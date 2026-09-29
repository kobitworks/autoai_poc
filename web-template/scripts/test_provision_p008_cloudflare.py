#!/usr/bin/env python3
import importlib.util
import os
import pathlib
import unittest
from unittest import mock

os.environ.setdefault("CLOUDFLARE_ACCOUNT_ID","test-account")
os.environ.setdefault("CLOUDFLARE_API_TOKEN","test-token")

MODULE_PATH=pathlib.Path(__file__).with_name("provision_p008_cloudflare.py")
SPEC=importlib.util.spec_from_file_location("provision_p008_cloudflare",MODULE_PATH)
m=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(m)

class OwnershipTests(unittest.TestCase):
    def single_env(self):
        return mock.patch.multiple(
            m,
            R2_NAMES={"staging":"p008-test-bucket"},
            ORIGINS={"staging":["https://kobitworks.github.io"]},
        )

    def test_existing_unowned_bucket_is_refused(self):
        with self.single_env(),              mock.patch.object(m,"ensure_ownership_table"),              mock.patch.object(m,"r2_find",return_value={"name":"p008-test-bucket"}),              mock.patch.object(m,"ownership_get",return_value=None):
            with self.assertRaisesRegex(RuntimeError,"without P008 ownership record"):
                m.provision_r2("d1-test")

    def test_new_bucket_reserves_before_create_and_activates(self):
        events=[]
        def reserve(*args):
            events.append("reserve")
            return {"project_id":"P008","resource_name":"p008-test-bucket","status":"reserved"}
        def request(method,url,payload=None):
            if method=="POST" and url.endswith("/r2/buckets"):
                events.append("create")
                return {"name":"p008-test-bucket"}
            if method=="PUT":
                events.append("cors-put")
                return {}
            if method=="GET" and url.endswith("/cors"):
                events.append("cors-get")
                return {"rules":[{"id":"ok"}]}
            raise AssertionError((method,url))
        def activate(*args):
            events.append("activate")
            return {"project_id":"P008","resource_name":"p008-test-bucket","status":"active"}

        with self.single_env(),              mock.patch.object(m,"ensure_ownership_table"),              mock.patch.object(m,"r2_find",return_value=None),              mock.patch.object(m,"ownership_get",return_value=None),              mock.patch.object(m,"ownership_reserve",side_effect=reserve),              mock.patch.object(m,"ownership_activate",side_effect=activate),              mock.patch.object(m,"verify_private",side_effect=lambda name: events.append("private")),              mock.patch.object(m,"req",side_effect=request):
            out=m.provision_r2("d1-test")

        self.assertLess(events.index("reserve"),events.index("create"))
        self.assertEqual(events[-1],"activate")
        self.assertEqual(out["staging"]["ownership_status"],"active")
        self.assertTrue(out["staging"]["created"])

    def test_reserved_existing_bucket_resumes_without_create(self):
        owner={"project_id":"P008","resource_name":"p008-test-bucket","status":"reserved"}
        calls=[]
        def request(method,url,payload=None):
            calls.append(method)
            if method=="PUT": return {}
            if method=="GET" and url.endswith("/cors"): return {"rules":[{"id":"ok"}]}
            raise AssertionError((method,url))
        with self.single_env(),              mock.patch.object(m,"ensure_ownership_table"),              mock.patch.object(m,"r2_find",return_value={"name":"p008-test-bucket"}),              mock.patch.object(m,"ownership_get",return_value=owner),              mock.patch.object(m,"ownership_reserve") as reserve,              mock.patch.object(m,"ownership_activate",return_value={**owner,"status":"active"}),              mock.patch.object(m,"verify_private"),              mock.patch.object(m,"req",side_effect=request):
            out=m.provision_r2("d1-test")
        reserve.assert_not_called()
        self.assertNotIn("POST",calls)
        self.assertFalse(out["staging"]["created"])

    def test_active_missing_bucket_is_not_silently_recreated(self):
        owner={"project_id":"P008","resource_name":"p008-test-bucket","status":"active"}
        with self.single_env(),              mock.patch.object(m,"ensure_ownership_table"),              mock.patch.object(m,"r2_find",return_value=None),              mock.patch.object(m,"ownership_get",return_value=owner):
            with self.assertRaisesRegex(RuntimeError,"refusing silent recreation"):
                m.provision_r2("d1-test")

    def test_owner_identity_mismatch_is_refused(self):
        owner={"project_id":"OTHER","resource_name":"p008-test-bucket","status":"reserved"}
        with self.assertRaisesRegex(RuntimeError,"ownership drift"):
            m.validate_owner(owner,"staging","p008-test-bucket")

    def test_reservation_is_persisted_as_reserved_state(self):
        row={"project_id":"P008","resource_name":"p008-test-bucket","status":"reserved"}
        with mock.patch.object(m,"ownership_get",side_effect=[None,row]),              mock.patch.object(m,"d1_query",return_value=[]) as query:
            got=m.ownership_reserve("d1-test","staging","p008-test-bucket")
        self.assertEqual(got["status"],"reserved")
        sql=query.call_args.args[1]
        self.assertIn("INSERT INTO _autoai_resource_ownership",sql)
        self.assertIn("'reserved'",sql)

if __name__=="__main__":
    unittest.main()
