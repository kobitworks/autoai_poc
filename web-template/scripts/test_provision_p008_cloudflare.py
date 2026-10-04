#!/usr/bin/env python3
import importlib.util
import os
import pathlib
import unittest
from unittest import mock

os.environ.setdefault("CLOUDFLARE_ACCOUNT_ID", "test-account")
os.environ.setdefault("CLOUDFLARE_API_TOKEN", "test-token")

MODULE_PATH = pathlib.Path(__file__).with_name("provision_p008_cloudflare.py")
SPEC = importlib.util.spec_from_file_location("provision_p008_cloudflare", MODULE_PATH)
m = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(m)


class ZeroCostGuardTests(unittest.TestCase):
    def test_workers_paid_subscription_is_refused(self):
        subscriptions = [
            {
                "state": "Paid",
                "rate_plan": {"id": "WORKERS_PAID"},
            }
        ]
        with mock.patch.object(m, "req", return_value=subscriptions):
            with self.assertRaisesRegex(RuntimeError, "Paid or billable Workers subscription"):
                m.verify_zero_cost_workers_plan()

    def test_partner_workers_paid_subscription_is_refused(self):
        subscriptions = [
            {
                "state": "Provisioned",
                "rate_plan": {"id": "PARTNERS_WORKERS_BASIC"},
            }
        ]
        with mock.patch.object(m, "req", return_value=subscriptions):
            with self.assertRaisesRegex(RuntimeError, "Paid or billable Workers subscription"):
                m.verify_zero_cost_workers_plan()

    def test_cancelled_paid_subscription_is_not_active(self):
        subscriptions = [
            {
                "state": "Cancelled",
                "rate_plan": {"id": "WORKERS_PAID"},
            }
        ]
        with mock.patch.object(m, "req", return_value=subscriptions):
            result = m.verify_zero_cost_workers_plan()
        self.assertTrue(result["checked"])
        self.assertFalse(result["paid_workers_subscription"])
        self.assertFalse(result["billing_changes"])

    def test_no_workers_subscription_means_free_default_is_allowed(self):
        subscriptions = [
            {
                "state": "Paid",
                "rate_plan": {"id": "IMAGES_BASIC"},
            }
        ]
        with mock.patch.object(m, "req", return_value=subscriptions):
            result = m.verify_zero_cost_workers_plan()
        self.assertTrue(result["checked"])
        self.assertFalse(result["paid_workers_subscription"])


if __name__ == "__main__":
    unittest.main()
