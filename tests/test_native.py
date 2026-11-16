import datetime
import importlib.machinery
import json
import pathlib
import sqlite3
import tempfile
import unittest

native = importlib.machinery.SourceFileLoader('native', str(pathlib.Path(__file__).resolve().parents[1] / 'bin' / 'cli-session-native')).load_module()


class CompletionTests(unittest.TestCase):
    def test_missing_agy_metadata_keeps_idle_fallback_available(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(native.agy_state(pathlib.Path(d) / 'missing.db', None, 0), 'unknown')

    def test_grok_old_turn_cannot_complete_new_dispatch(self):
        with tempfile.TemporaryDirectory() as d:
            p = pathlib.Path(d) / 'events.jsonl'
            p.write_text(json.dumps({'type': 'turn_started'}) + '\n' + json.dumps({'type': 'turn_ended', 'outcome': 'completed'}) + '\n')
            offset = p.stat().st_size
            self.assertEqual(native.grok_state(p, offset), 'pending')
            with p.open('a') as f:
                f.write(json.dumps({'type': 'turn_started'}) + '\n')
            self.assertEqual(native.grok_state(p, offset), 'busy')
            with p.open('a') as f:
                f.write(json.dumps({'type': 'turn_ended', 'outcome': 'completed'}) + '\n')
            # Works even when no observer was present while the turn was busy.
            self.assertEqual(native.grok_state(p, offset), 'done')

    def test_grok_failure_and_truncated_log_are_not_success(self):
        with tempfile.TemporaryDirectory() as d:
            p = pathlib.Path(d) / 'events.jsonl'
            p.write_text('{"type":"turn_started"}\n{"type":"turn_ended","outcome":"error"}\n')
            self.assertEqual(native.grok_state(p, 0), 'failed')
            self.assertEqual(native.grok_state(p, p.stat().st_size + 1), 'unknown')

    def test_agy_exact_id_timestamp_and_idle_state(self):
        with tempfile.TemporaryDirectory() as d:
            p = pathlib.Path(d) / 'state.db'
            db = sqlite3.connect(p)
            db.execute('CREATE TABLE conversation_summaries(conversation_id TEXT,status TEXT,not_fully_idle INTEGER,last_user_input_time TEXT)')
            db.execute('INSERT INTO conversation_summaries VALUES(?,?,?,?)', ('ours', 'CASCADE_RUN_STATUS_IDLE', 0, '2026-11-16 14:00:01+00:00'))
            db.commit()
            before = datetime.datetime.fromisoformat('2026-11-16T14:00:00+00:00').timestamp()
            self.assertEqual(native.agy_state(p, 'ours', before), 'done')
            self.assertEqual(native.agy_state(p, 'other', before), 'pending')
            self.assertEqual(native.agy_state(p, 'ours', before + 2), 'pending')
            db.execute('UPDATE conversation_summaries SET not_fully_idle=1')
            db.commit()
            self.assertEqual(native.agy_state(p, 'ours', before), 'busy')
            db.close()


if __name__ == '__main__':
    unittest.main()
