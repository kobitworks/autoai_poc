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

    def test_existing_unmarked_bucket_is_refused(self):
        with self.single_env(),              mock.patch.object(m,"r2_find",return_value={"name":"p008-test-bucket"}),              mock.patch.object(m,"has_ownership_marker",return_value=False):
            with self.assertRaisesRegex(RuntimeError,"without P008 ownership marker"):
                m.provision_r2()

    def test_new_bucket_gets_marker_before_normal_validation(self):
        events=[]
        def create(name,env):
            events.append("create-owned")
            return {"name":name}
        with self.single_env(),              mock.patch.object(m,"r2_find",return_value=None),              mock.patch.object(m,"create_owned_bucket",side_effect=create),              mock.patch.object(m,"verify_private",side_effect=lambda name: events.append("private")),              mock.patch.object(m,"put_managed_cors",side_effect=lambda name,env: events.append("cors-refresh")):
            out=m.provision_r2()
        self.assertEqual(events[0],"create-owned")
        self.assertIn("private",events)
        self.assertTrue(out["staging"]["created"])
        self.assertEqual(out["staging"]["ownership_marker"],"autoai-p008-staging-owned-v1")

    def test_marked_existing_bucket_resumes_without_create(self):
        with self.single_env(),              mock.patch.object(m,"r2_find",return_value={"name":"p008-test-bucket"}),              mock.patch.object(m,"has_ownership_marker",return_value=True),              mock.patch.object(m,"create_owned_bucket") as create,              mock.patch.object(m,"verify_private"),              mock.patch.object(m,"put_managed_cors"):
            out=m.provision_r2()
        create.assert_not_called()
        self.assertFalse(out["staging"]["created"])

    def test_marker_failure_rolls_back_new_empty_bucket(self):
        events=[]
        def request(method,url,payload=None):
            if method=="POST" and url.endswith("/r2/buckets"):
                events.append("create")
                return {"name":"p008-test-bucket"}
            raise AssertionError((method,url))
        with mock.patch.object(m,"req",side_effect=request),              mock.patch.object(m,"put_managed_cors",side_effect=RuntimeError("marker failed")),              mock.patch.object(m,"rollback_new_bucket",side_effect=lambda name: events.append("rollback")):
            with self.assertRaisesRegex(RuntimeError,"rolled back"):
                m.create_owned_bucket("p008-test-bucket","staging")
        self.assertEqual(events,["create","rollback"])

    def test_marker_and_rollback_failure_is_explicit(self):
        def request(method,url,payload=None):
            if method=="POST" and url.endswith("/r2/buckets"):
                return {"name":"p008-test-bucket"}
            raise AssertionError((method,url))
        with mock.patch.object(m,"req",side_effect=request),              mock.patch.object(m,"put_managed_cors",side_effect=RuntimeError("marker failed")),              mock.patch.object(m,"rollback_new_bucket",side_effect=RuntimeError("delete failed")):
            with self.assertRaisesRegex(RuntimeError,"rollback also failed"):
                m.create_owned_bucket("p008-test-bucket","staging")

    def test_ownership_marker_is_project_and_environment_specific(self):
        self.assertEqual(m.ownership_rule_id("staging"),"autoai-p008-staging-owned-v1")
        self.assertEqual(m.ownership_rule_id("production"),"autoai-p008-production-owned-v1")
        staging=m.cors_rules("staging",["https://kobitworks.github.io"])
        production=m.cors_rules("production",["https://kobitworks.github.io"])
        self.assertNotEqual(staging[0]["id"],production[0]["id"])
        self.assertEqual(staging[0]["allowed"]["methods"],["GET","HEAD","PUT"])

if __name__=="__main__":
    unittest.main()
