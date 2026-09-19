import json
import unittest

from python.deixic_examples.account_brief_result import parse_account_brief


BRIEF = {
    "schemaVersion": "deixic.account-brief.v1",
    "accountName": "Example account",
    "summary": {"text": "Renewal due", "sourceIds": ["account"]},
    "opportunities": [],
    "risks": [],
    "sources": [{"id": "account", "system": "crm", "resourceId": "account-1"}],
    "missingData": [],
}


class AccountBriefResultTest(unittest.TestCase):
    def test_accepts_linked_facts(self):
        self.assertEqual(parse_account_brief(json.dumps(BRIEF)), BRIEF)

    def test_rejects_unlinked_facts(self):
        changed = json.loads(json.dumps(BRIEF))
        changed["summary"]["sourceIds"] = ["missing"]
        with self.assertRaises(ValueError):
            parse_account_brief(json.dumps(changed))

    def test_rejects_duplicate_keys(self):
        with self.assertRaises(ValueError):
            parse_account_brief('{"schemaVersion":"one","schemaVersion":"two"}')


if __name__ == "__main__":
    unittest.main()
