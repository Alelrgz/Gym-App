import unittest
from unittest.mock import MagicMock, patch
import json
from datetime import date, timedelta

# Mock the database dependencies before importing services
import sys
sys.modules['database'] = MagicMock()
sys.modules['models_orm'] = MagicMock()
sys.modules['models_client_orm'] = MagicMock()
sys.modules['data'] = MagicMock()

# Now import the service to test
from services import UserService

class TestSplitAssignment(unittest.TestCase):
    def setUp(self):
        self.service = UserService()
        self.trainer_id = "trainer_test"
        self.client_id = "client_test"
        self.split_id = "split_test"
        self.start_date = "2025-01-01" # Wednesday

    @patch('services.get_trainer_session')
    @patch('services.UserService.assign_workout')
    def test_assign_split_success(self, mock_assign_workout, mock_get_trainer_session):
        # Setup Mock DB Session for Trainer
        mock_db = MagicMock()
        mock_get_trainer_session.return_value = mock_db
        
        # Setup Mock Split
        mock_split = MagicMock()
        mock_split.id = self.split_id
        mock_split.days_per_week = 7
        # Schedule: Wednesday is Leg Day
        mock_split.schedule_json = json.dumps({
            "Monday": "workout_1",
            "Wednesday": "workout_2", # Should be assigned on Jan 1st
            "Friday": "workout_3"
        })
        
        mock_db.query.return_value.filter.return_value.first.return_value = mock_split
        
        # Mock assign_workout to return success
        mock_assign_workout.return_value = {"status": "success"}
        
        # Execute
        assignment = {
            "client_id": self.client_id,
            "split_id": self.split_id,
            "start_date": self.start_date
        }
        result = self.service.assign_split(assignment, self.trainer_id)
        
        # Verify
        self.assertEqual(result["status"], "success")
        self.assertIn("logs", result)
        
        # Verify assign_workout was called
        # We expect it to be called for the 4 weeks
        # Jan 1 is Wednesday. Schedule has Wednesday = workout_2.
        # So we expect workout_2 to be assigned on Jan 1, Jan 8, Jan 15, Jan 22.
        
        # Check calls
        calls = mock_assign_workout.call_args_list
        print(f"Assign Workout called {len(calls)} times")
        
        # Verify at least one correct call
        expected_call_arg = {
            "client_id": self.client_id,
            "workout_id": "workout_2",
            "date": "2025-01-01"
        }
        
        found = False
        for call in calls:
            args, _ = call
            if args[0] == expected_call_arg:
                found = True
                break
        
        self.assertTrue(found, "Did not find assignment for Jan 1st (Wednesday)")

if __name__ == '__main__':
    unittest.main()
