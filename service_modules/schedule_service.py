"""
Schedule Service - handles trainer events, client schedules, and workout completion.
"""
from .base import (
    HTTPException, json, logging, date, datetime, timedelta,
    get_db_session, TrainerScheduleORM, ClientScheduleORM, ClientExerciseLogORM, UserORM,
    ClientProfileORM
)

logger = logging.getLogger("gym_app")


class ScheduleService:
    """Service for managing schedules, events, and workout completion."""

    # Time utility methods
    def _parse_time(self, time_str: str):
        """Convert '9:00 AM' to datetime.time object"""
        try:
            return datetime.strptime(time_str, "%I:%M %p").time()
        except ValueError:
            # Try without AM/PM
            try:
                return datetime.strptime(time_str, "%H:%M").time()
            except ValueError:
                raise HTTPException(status_code=400, detail=f"Invalid time format: {time_str}")

    def _add_minutes_to_time(self, time_obj, minutes: int):
        """Add minutes to a time object, returns new time"""
        dt = datetime.combine(datetime.today(), time_obj)
        return (dt + timedelta(minutes=minutes)).time()

    def _times_overlap(self, start1, end1, start2, end2):
        """Check if two time ranges overlap"""
        return start1 < end2 and end1 > start2

    def _check_schedule_conflict(self, trainer_id: str, date: str, time: str, duration: int, db, exclude_event_id=None):
        """
        Check if a new event conflicts with existing events

        Returns:
            (has_conflict: bool, conflicting_event: dict or None)
        """
        try:
            # Parse start and end times
            start_time = self._parse_time(time)
            end_time = self._add_minutes_to_time(start_time, duration)

            # Get all events on the same date for this trainer
            query = db.query(TrainerScheduleORM).filter(
                TrainerScheduleORM.trainer_id == trainer_id,
                TrainerScheduleORM.date == date
            )

            if exclude_event_id:
                query = query.filter(TrainerScheduleORM.id != exclude_event_id)

            existing_events = query.all()

            # Check for overlaps
            for event in existing_events:
                event_start = self._parse_time(event.time)
                event_duration = event.duration if event.duration else 60  # Default 60 min
                event_end = self._add_minutes_to_time(event_start, event_duration)

                # Check if times overlap
                if self._times_overlap(start_time, end_time, event_start, event_end):
                    return True, {
                        "id": event.id,
                        "title": event.title,
                        "time": event.time,
                        "duration": event_duration
                    }

            return False, None
        except Exception as e:
            logger.error(f"Error checking schedule conflict: {e}")
            return False, None

    # Trainer event methods
    def add_trainer_event(self, event_data: dict, trainer_id: str):
        """Add an event to trainer's schedule."""
        db = get_db_session()
        try:
            duration = event_data.get("duration", 60)  # Default 60 minutes

            # If this is a workout event, replace any existing workout for the same day
            # Workouts don't check for conflicts - they just replace existing workouts
            if event_data.get("workout_id"):
                existing_workout_events = db.query(TrainerScheduleORM).filter(
                    TrainerScheduleORM.trainer_id == trainer_id,
                    TrainerScheduleORM.date == event_data["date"],
                    TrainerScheduleORM.workout_id != None
                ).all()

                for existing_event in existing_workout_events:
                    db.delete(existing_event)

                # Commit the deletions before adding the new event
                db.commit()
            else:
                # For non-workout events (calendar events, consultations, etc.), check for conflicts
                has_conflict, conflict = self._check_schedule_conflict(
                    trainer_id,
                    event_data["date"],
                    event_data["time"],
                    duration,
                    db
                )

                if has_conflict:
                    raise HTTPException(
                        status_code=409,
                        detail=f"Schedule conflict with '{conflict['title']}' at {conflict['time']} ({conflict['duration']} min)"
                    )

            # Create new event
            new_event = TrainerScheduleORM(
                trainer_id=trainer_id,
                date=event_data["date"],
                time=event_data["time"],
                title=event_data["title"],
                subtitle=event_data.get("subtitle"),
                type=event_data["type"],
                duration=duration,
                workout_id=event_data.get("workout_id"),
                course_id=event_data.get("course_id")
            )
            db.add(new_event)
            db.commit()
            db.refresh(new_event)
            return {"status": "success", "event_id": new_event.id}
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to add event: {str(e)}")
        finally:
            db.close()

    def remove_trainer_event(self, event_id: str, trainer_id: str):
        """Remove an event from trainer's schedule."""
        db = get_db_session()
        try:
            event = db.query(TrainerScheduleORM).filter(
                TrainerScheduleORM.id == int(event_id),
                TrainerScheduleORM.trainer_id == trainer_id
            ).first()

            if not event:
                raise HTTPException(status_code=404, detail="Event not found")

            db.delete(event)
            db.commit()
            return {"status": "success", "message": "Event deleted"}
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to delete event: {str(e)}")
        finally:
            db.close()

    def get_affected_people(self, event, db) -> list:
        """Get list of people affected by an event change (clients, course participants)."""
        affected = []
        # 1-on-1 appointment: the client is affected
        if event.client_id:
            client = db.query(UserORM).filter(UserORM.id == event.client_id).first()
            if client:
                affected.append({"id": client.id, "name": client.username, "type": "client"})
        # Course lesson: all enrolled clients with this course scheduled are affected
        if event.course_id:
            from models_orm import ClientScheduleORM as CSO
            enrolled = db.query(CSO).filter(
                CSO.course_id == event.course_id,
                CSO.date == event.date
            ).all()
            seen_ids = set()
            for entry in enrolled:
                if entry.client_id not in seen_ids:
                    seen_ids.add(entry.client_id)
                    user = db.query(UserORM).filter(UserORM.id == entry.client_id).first()
                    if user:
                        affected.append({"id": user.id, "name": user.username, "type": "course_member"})
        return affected

    def _notify_schedule_change(self, affected_people: list, event, old_date: str, old_time: str, new_date: str, new_time: str):
        """Send in-app notifications to affected people about a schedule change."""
        from service_modules.notification_service import get_notification_service
        notif_service = get_notification_service()

        for person in affected_people:
            notif_service.create_notification(
                user_id=person["id"],
                notification_type="schedule_changed",
                title="Orario modificato",
                message=f"'{event.title}' spostato da {old_date} {old_time} a {new_date} {new_time}",
                data={
                    "event_id": event.id,
                    "event_title": event.title,
                    "old_date": old_date,
                    "old_time": old_time,
                    "new_date": new_date,
                    "new_time": new_time
                }
            )

    def update_trainer_event(self, event_id: str, updates: dict, trainer_id: str) -> dict:
        """Update an existing trainer event (time, date, duration, etc)."""
        db = get_db_session()
        try:
            event = db.query(TrainerScheduleORM).filter(
                TrainerScheduleORM.id == int(event_id),
                TrainerScheduleORM.trainer_id == trainer_id
            ).first()

            if not event:
                raise HTTPException(status_code=404, detail="Event not found")

            old_date = event.date
            old_time = event.time

            # Check for conflicts if time/date/duration changed
            new_date = updates.get("date", event.date)
            new_time = updates.get("time", event.time)
            new_duration = updates.get("duration", event.duration or 60)

            if new_date != event.date or new_time != event.time or new_duration != event.duration:
                has_conflict, conflict = self._check_schedule_conflict(
                    trainer_id, new_date, new_time, new_duration, db,
                    exclude_event_id=int(event_id)
                )
                if has_conflict:
                    raise HTTPException(
                        status_code=409,
                        detail=f"Schedule conflict with '{conflict['title']}' at {conflict['time']}"
                    )

            # Check if this is a dry_run (just checking affected people)
            if updates.get("dry_run"):
                affected = self.get_affected_people(event, db)
                return {
                    "status": "dry_run",
                    "affected_people": affected,
                    "event_title": event.title,
                    "old_date": old_date,
                    "old_time": old_time,
                    "new_date": new_date,
                    "new_time": new_time
                }

            # Get affected people before applying changes
            schedule_changed = (new_date != old_date or new_time != old_time)
            affected = self.get_affected_people(event, db) if schedule_changed else []

            # Apply updates
            if "date" in updates:
                event.date = updates["date"]
            if "time" in updates:
                event.time = updates["time"]
            if "duration" in updates:
                event.duration = updates["duration"]
            if "title" in updates:
                event.title = updates["title"]
            if "subtitle" in updates:
                event.subtitle = updates["subtitle"]

            # Also update client schedule entries for courses
            if schedule_changed and event.course_id:
                from models_orm import ClientScheduleORM as CSO
                client_entries = db.query(CSO).filter(
                    CSO.course_id == event.course_id,
                    CSO.date == old_date
                ).all()
                for entry in client_entries:
                    entry.date = new_date

            db.commit()
            db.refresh(event)

            # Notify affected people after successful commit
            if affected and schedule_changed:
                try:
                    self._notify_schedule_change(affected, event, old_date, old_time, new_date, new_time)
                except Exception as e:
                    logger.error(f"Failed to send schedule change notifications: {e}")

            return {
                "status": "success",
                "affected_count": len(affected),
                "event": {
                    "id": event.id,
                    "date": event.date,
                    "time": event.time,
                    "title": event.title,
                    "subtitle": event.subtitle,
                    "duration": event.duration,
                    "completed": event.completed,
                    "course_id": event.course_id
                }
            }
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to update event: {str(e)}")
        finally:
            db.close()

    def reschedule_series(self, event_id: str, updates: dict, trainer_id: str) -> dict:
        """Reschedule all future occurrences of a recurring (course-based) event series.

        Calculates the time delta from the moved event and applies it to all
        future non-completed events sharing the same course_id.
        """
        db = get_db_session()
        try:
            event = db.query(TrainerScheduleORM).filter(
                TrainerScheduleORM.id == int(event_id),
                TrainerScheduleORM.trainer_id == trainer_id
            ).first()

            if not event:
                raise HTTPException(status_code=404, detail="Event not found")

            if not event.course_id:
                raise HTTPException(status_code=400, detail="Event is not part of a recurring series")

            old_date = event.date
            old_time = event.time
            new_date = updates.get("date", old_date)
            new_time = updates.get("time", old_time)

            if new_date == old_date and new_time == old_time:
                return {"status": "no_change", "moved_count": 0}

            # Calculate day delta
            from datetime import datetime as dt
            old_dt = dt.strptime(old_date, "%Y-%m-%d")
            new_dt = dt.strptime(new_date, "%Y-%m-%d")
            day_delta = (new_dt - old_dt).days

            # Calculate time delta in minutes
            old_time_obj = self._parse_time(old_time)
            new_time_obj = self._parse_time(new_time)
            old_minutes = old_time_obj.hour * 60 + old_time_obj.minute
            new_minutes = new_time_obj.hour * 60 + new_time_obj.minute
            time_delta_minutes = new_minutes - old_minutes

            # Get all future non-completed events in this course series (including the current one)
            future_events = db.query(TrainerScheduleORM).filter(
                TrainerScheduleORM.trainer_id == trainer_id,
                TrainerScheduleORM.course_id == event.course_id,
                TrainerScheduleORM.date >= old_date,
                TrainerScheduleORM.completed == False
            ).all()

            if updates.get("dry_run"):
                # Collect all affected people across all future events
                all_affected = []
                seen_ids = set()
                for evt in future_events:
                    for person in self.get_affected_people(evt, db):
                        if person["id"] not in seen_ids:
                            seen_ids.add(person["id"])
                            all_affected.append(person)
                return {
                    "status": "dry_run",
                    "affected_people": all_affected,
                    "events_count": len(future_events),
                    "event_title": event.title,
                    "old_date": old_date,
                    "old_time": old_time,
                    "new_date": new_date,
                    "new_time": new_time
                }

            # Collect all affected people before modifying
            all_affected = []
            seen_ids = set()
            for evt in future_events:
                for person in self.get_affected_people(evt, db):
                    if person["id"] not in seen_ids:
                        seen_ids.add(person["id"])
                        all_affected.append(person)

            moved_count = 0
            for evt in future_events:
                evt_old_date = evt.date
                # Shift date
                evt_dt = dt.strptime(evt.date, "%Y-%m-%d") + timedelta(days=day_delta)
                evt.date = evt_dt.strftime("%Y-%m-%d")

                # Shift time
                evt_time_obj = self._parse_time(evt.time)
                shifted = self._add_minutes_to_time(evt_time_obj, time_delta_minutes)
                evt.time = shifted.strftime("%H:%M")

                # Also shift client schedule entries for this course on the old date
                from models_orm import ClientScheduleORM as CSO
                client_entries = db.query(CSO).filter(
                    CSO.course_id == event.course_id,
                    CSO.date == evt_old_date
                ).all()
                for entry in client_entries:
                    entry.date = evt.date

                moved_count += 1

            db.commit()

            # Notify all unique affected people
            if all_affected:
                try:
                    from service_modules.notification_service import get_notification_service
                    notif_service = get_notification_service()
                    for person in all_affected:
                        notif_service.create_notification(
                            user_id=person["id"],
                            notification_type="schedule_changed",
                            title="Orario serie modificato",
                            message=f"Il corso '{event.title}' è stato spostato. {moved_count} lezioni aggiornate.",
                            data={
                                "course_id": event.course_id,
                                "event_title": event.title,
                                "moved_count": moved_count
                            }
                        )
                except Exception as e:
                    logger.error(f"Failed to send series reschedule notifications: {e}")

            return {
                "status": "success",
                "moved_count": moved_count,
                "affected_count": len(all_affected)
            }
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to reschedule series: {str(e)}")
        finally:
            db.close()

    def delete_course_schedule_entries(self, course_id: str, trainer_id: str) -> dict:
        """Delete all schedule entries for a course (used when course is deleted)."""
        db = get_db_session()
        try:
            deleted = db.query(TrainerScheduleORM).filter(
                TrainerScheduleORM.course_id == course_id,
                TrainerScheduleORM.trainer_id == trainer_id
            ).delete()
            db.commit()
            return {"status": "success", "deleted_count": deleted}
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to delete course schedule: {str(e)}")
        finally:
            db.close()

    def toggle_trainer_event_completion(self, event_id: str, trainer_id: str) -> dict:
        """Toggle completion status of a trainer event."""
        db = get_db_session()
        try:
            event = db.query(TrainerScheduleORM).filter(
                TrainerScheduleORM.id == event_id,
                TrainerScheduleORM.trainer_id == trainer_id
            ).first()

            if not event:
                raise HTTPException(status_code=404, detail="Event not found")

            # Toggle
            event.completed = not event.completed
            db.commit()
            db.refresh(event)

            return {
                "status": "success",
                "message": "Event updated",
                "event_id": event_id,
                "completed": event.completed
            }
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to toggle event: {str(e)}")
        finally:
            db.close()

    # Client schedule methods
    def get_client_schedule(self, client_id: str, date_str: str = None) -> dict:
        """Get client's schedule for a given date."""
        if not date_str:
            date_str = date.today().isoformat()

        db = get_db_session()
        try:
            events = db.query(ClientScheduleORM).filter(
                ClientScheduleORM.client_id == client_id,
                ClientScheduleORM.date == date_str
            ).all()

            return {
                "date": date_str,
                "events": [
                    {
                        "id": e.id,
                        "title": e.title,
                        "type": e.type,
                        "completed": e.completed,
                        "workout_id": e.workout_id,
                        "details": e.details,
                        "appointment_id": getattr(e, 'appointment_id', None)
                    } for e in events
                ]
            }
        finally:
            db.close()

    def complete_schedule_item(self, payload: dict, client_id: str) -> dict:
        """Mark a client's schedule item as complete and save performance data."""
        date_str = payload.get("date")
        item_id = payload.get("item_id")

        db = get_db_session()
        try:
            # If we have ID, use it with client_id ownership check
            if item_id:
                item = db.query(ClientScheduleORM).filter(
                    ClientScheduleORM.id == item_id,
                    ClientScheduleORM.client_id == client_id  # Security check
                ).first()
            else:
                # Fallback
                item = db.query(ClientScheduleORM).filter(
                    ClientScheduleORM.client_id == client_id,
                    ClientScheduleORM.date == date_str,
                    ClientScheduleORM.type == "workout"
                ).first()

            if not item:
                raise HTTPException(status_code=404, detail="Schedule item not found")

            item.completed = True

            # Save Exercise Logs
            exercises = payload.get("exercises", [])
            if exercises:
                today_iso = date_str

                for ex in exercises:
                    ex_name = ex.get("name")
                    perf_list = ex.get("performance", [])

                    for i, perf in enumerate(perf_list):
                        if perf.get("completed"):
                            log = ClientExerciseLogORM(
                                client_id=client_id,
                                date=today_iso,
                                workout_id=item.workout_id,
                                exercise_name=ex_name,
                                set_number=i + 1,
                                reps=int(perf.get("reps", 0) or 0),
                                weight=float(perf.get("weight", 0) or 0),
                                metric_type="weight_reps"
                            )
                            db.add(log)

            # Save detailed snapshot
            item.details = json.dumps(exercises)

            db.commit()
            return {"status": "success", "message": "Workout completed!"}
        finally:
            db.close()

    def complete_coop_workout(self, payload: dict, user_id: str) -> dict:
        """Complete a CO-OP workout - logs completion for both user and partner."""
        from service_modules.friend_service import get_friend_service

        date_str = payload.get("date")
        partner_id = payload.get("partner_id")
        exercises = payload.get("exercises", [])
        partner_exercises = payload.get("partner_exercises", exercises)  # Use separate partner exercises if provided

        if not partner_id:
            raise HTTPException(status_code=400, detail="Partner ID required for CO-OP workout")

        # Verify they are friends
        friend_service = get_friend_service()
        if not friend_service.are_friends(user_id, partner_id):
            raise HTTPException(status_code=403, detail="You can only do CO-OP workouts with friends")

        db = get_db_session()
        try:
            # Get user's schedule item
            user_item = db.query(ClientScheduleORM).filter(
                ClientScheduleORM.client_id == user_id,
                ClientScheduleORM.date == date_str,
                ClientScheduleORM.type == "workout"
            ).first()

            # Get partner's schedule item
            partner_item = db.query(ClientScheduleORM).filter(
                ClientScheduleORM.client_id == partner_id,
                ClientScheduleORM.date == date_str,
                ClientScheduleORM.type == "workout"
            ).first()

            # Get partner's user info for storing in details
            partner_user = db.query(UserORM).filter(UserORM.id == partner_id).first()
            partner_info = {
                "id": partner_id,
                "name": partner_user.username if partner_user else "Partner",
                "profile_picture": partner_user.profile_picture if partner_user else None
            }

            if not user_item:
                raise HTTPException(status_code=404, detail="You don't have a workout scheduled for today")

            # Mark user's workout as complete - store with CO-OP info
            user_item.completed = True
            user_item.details = json.dumps({
                "exercises": exercises,
                "coop": {
                    "partner": partner_info,
                    "partner_exercises": partner_exercises
                }
            })

            # Save exercise logs for user
            for ex in exercises:
                ex_name = ex.get("name")
                perf_list = ex.get("performance", [])

                for i, perf in enumerate(perf_list):
                    if perf.get("completed"):
                        log = ClientExerciseLogORM(
                            client_id=user_id,
                            date=date_str,
                            workout_id=user_item.workout_id,
                            exercise_name=ex_name,
                            set_number=i + 1,
                            reps=int(perf.get("reps", 0) or 0),
                            weight=float(perf.get("weight", 0) or 0),
                            metric_type="weight_reps"
                        )
                        db.add(log)

            # Get current user info for partner's CO-OP reference
            current_user = db.query(UserORM).filter(UserORM.id == user_id).first()
            user_info = {
                "id": user_id,
                "name": current_user.username if current_user else "Partner",
                "profile_picture": current_user.profile_picture if current_user else None
            }

            # If partner has a workout scheduled, complete it too
            if partner_item:
                partner_item.completed = True
                partner_item.details = json.dumps({
                    "exercises": partner_exercises,
                    "coop": {
                        "partner": user_info,
                        "partner_exercises": exercises  # User's exercises from partner's perspective
                    }
                })

                # Save exercise logs for partner (using partner's exercise data)
                for ex in partner_exercises:
                    ex_name = ex.get("name")
                    perf_list = ex.get("performance", [])

                    for i, perf in enumerate(perf_list):
                        if perf.get("completed"):
                            log = ClientExerciseLogORM(
                                client_id=partner_id,
                                date=date_str,
                                workout_id=partner_item.workout_id,
                                exercise_name=ex_name,
                                set_number=i + 1,
                                reps=int(perf.get("reps", 0) or 0),
                                weight=float(perf.get("weight", 0) or 0),
                                metric_type="weight_reps"
                            )
                            db.add(log)

                # Award gems to both users for completing workout (CO-OP bonus!)
                WORKOUT_GEMS = 50  # Base gems for workout
                COOP_BONUS = 25   # Extra gems for CO-OP
                total_gems = WORKOUT_GEMS + COOP_BONUS

                # Award to user
                user_profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == user_id).first()
                if user_profile:
                    user_profile.gems = (user_profile.gems or 0) + total_gems

                # Award to partner
                partner_profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == partner_id).first()
                if partner_profile:
                    partner_profile.gems = (partner_profile.gems or 0) + total_gems

                db.commit()
                return {
                    "status": "success",
                    "message": "CO-OP workout completed for both of you!",
                    "partner_completed": True,
                    "gems_awarded": total_gems
                }
            else:
                # Partner doesn't have a workout today - create one based on user's workout
                new_partner_item = ClientScheduleORM(
                    client_id=partner_id,
                    date=date_str,
                    type="workout",
                    workout_id=user_item.workout_id,
                    title=user_item.title,
                    completed=True,
                    details=json.dumps({
                        "exercises": partner_exercises,
                        "coop": {
                            "partner": user_info,
                            "partner_exercises": exercises
                        }
                    })
                )
                db.add(new_partner_item)

                # Save exercise logs for partner
                for ex in exercises:
                    ex_name = ex.get("name")
                    perf_list = ex.get("performance", [])

                    for i, perf in enumerate(perf_list):
                        if perf.get("completed"):
                            log = ClientExerciseLogORM(
                                client_id=partner_id,
                                date=date_str,
                                workout_id=user_item.workout_id,
                                exercise_name=ex_name,
                                set_number=i + 1,
                                reps=int(perf.get("reps", 0) or 0),
                                weight=float(perf.get("weight", 0) or 0),
                                metric_type="weight_reps"
                            )
                            db.add(log)

                # Award gems to both users for completing workout (CO-OP bonus!)
                WORKOUT_GEMS = 50  # Base gems for workout
                COOP_BONUS = 25   # Extra gems for CO-OP
                total_gems = WORKOUT_GEMS + COOP_BONUS

                # Award to user
                user_profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == user_id).first()
                if user_profile:
                    user_profile.gems = (user_profile.gems or 0) + total_gems

                # Award to partner
                partner_profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == partner_id).first()
                if partner_profile:
                    partner_profile.gems = (partner_profile.gems or 0) + total_gems

                db.commit()
                return {
                    "status": "success",
                    "message": "CO-OP workout completed! Added to your friend's schedule too.",
                    "partner_completed": True,
                    "gems_awarded": total_gems
                }
        finally:
            db.close()

    def complete_trainer_schedule_item(self, payload: dict, trainer_id: str) -> dict:
        """Mark a trainer's personal workout schedule item as complete and save performance data."""
        date_str = payload.get("date")
        exercises = payload.get("exercises", [])

        db = get_db_session()
        try:
            # Find trainer's workout event for the given date
            item = db.query(TrainerScheduleORM).filter(
                TrainerScheduleORM.trainer_id == trainer_id,
                TrainerScheduleORM.date == date_str,
                TrainerScheduleORM.workout_id != None  # Must have a workout attached
            ).first()

            if not item:
                raise HTTPException(status_code=404, detail="Trainer schedule item not found")

            item.completed = True

            # Save detailed snapshot (just like client)
            if exercises:
                item.details = json.dumps(exercises)

            db.commit()
            return {"status": "success", "message": "Trainer workout completed!"}
        finally:
            db.close()

    def update_completed_workout(self, payload: dict, client_id: str) -> dict:
        """Update a single set in a completed workout."""
        date_str = payload.get("date")
        workout_id = payload.get("workout_id")

        exercise_name = payload.get("exercise_name")
        set_number = int(payload.get("set_number"))
        reps = payload.get("reps")
        weight = payload.get("weight")
        duration = payload.get("duration")  # For cardio (in minutes)
        distance = payload.get("distance")  # For cardio (in km)
        metric_type = payload.get("metric_type", "weight_reps")

        db = get_db_session()
        try:
            # 1. Update Log
            log = db.query(ClientExerciseLogORM).filter(
                ClientExerciseLogORM.client_id == client_id,
                ClientExerciseLogORM.date == date_str,
                ClientExerciseLogORM.workout_id == workout_id,
                ClientExerciseLogORM.exercise_name == exercise_name,
                ClientExerciseLogORM.set_number == set_number
            ).first()

            if log:
                log.reps = int(reps) if reps else 0
                log.weight = float(weight) if weight else 0.0
                log.duration = float(duration) if duration else None
                log.distance = float(distance) if distance else None
                log.metric_type = metric_type
            else:
                log = ClientExerciseLogORM(
                    client_id=client_id,
                    date=date_str,
                    workout_id=workout_id,
                    exercise_name=exercise_name,
                    set_number=set_number,
                    reps=int(reps) if reps else 0,
                    weight=float(weight) if weight else 0.0,
                    duration=float(duration) if duration else None,
                    distance=float(distance) if distance else None,
                    metric_type=metric_type
                )
                db.add(log)

            # 2. Update Snapshot
            item = db.query(ClientScheduleORM).filter(
                ClientScheduleORM.client_id == client_id,
                ClientScheduleORM.date == date_str,
                ClientScheduleORM.workout_id == workout_id,
                ClientScheduleORM.type == "workout"
            ).first()

            if item and item.details:
                try:
                    exercises = json.loads(item.details)
                    for ex in exercises:
                        if ex.get("name") == exercise_name:
                            perf_list = ex.get("performance", [])
                            while len(perf_list) < set_number:
                                perf_list.append({"reps": "", "weight": "", "duration": "", "distance": "", "completed": False})

                            perf_list[set_number - 1]["reps"] = reps
                            perf_list[set_number - 1]["weight"] = weight
                            perf_list[set_number - 1]["duration"] = duration
                            perf_list[set_number - 1]["distance"] = distance
                            perf_list[set_number - 1]["completed"] = True
                            break

                    item.details = json.dumps(exercises)
                except Exception as e:
                    print(f"Error updating snapshot: {e}")

            db.commit()
            return {"status": "success"}
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to update set: {str(e)}")
        finally:
            db.close()

    def get_client_workout_log(self, client_id: str, limit: int = 30) -> list:
        """Get detailed workout logs for a client, grouped by date with individual sets."""
        db = get_db_session()
        try:
            logs = db.query(ClientExerciseLogORM).filter(
                ClientExerciseLogORM.client_id == client_id
            ).order_by(
                ClientExerciseLogORM.date.desc(),
                ClientExerciseLogORM.exercise_name,
                ClientExerciseLogORM.set_number
            ).all()

            # Group by date, then by exercise
            from collections import OrderedDict
            days = OrderedDict()
            for log in logs:
                date = log.date
                if date not in days:
                    days[date] = OrderedDict()
                ex_name = log.exercise_name or 'Unknown'
                if ex_name not in days[date]:
                    days[date][ex_name] = {
                        'exercise_name': ex_name,
                        'metric_type': log.metric_type or 'weight_reps',
                        'sets': []
                    }
                days[date][ex_name]['sets'].append({
                    'set_number': log.set_number,
                    'reps': log.reps,
                    'weight': log.weight,
                    'duration': log.duration,
                    'distance': log.distance,
                })

            result = []
            for date, exercises in list(days.items())[:limit]:
                result.append({
                    'date': date,
                    'exercises': list(exercises.values())
                })

            return result
        finally:
            db.close()

    def get_client_course_log(self, client_id: str, limit: int = 50) -> list:
        """Get completed course schedule entries for a client."""
        db = get_db_session()
        try:
            courses = db.query(ClientScheduleORM).filter(
                ClientScheduleORM.client_id == client_id,
                ClientScheduleORM.type == "course",
                ClientScheduleORM.completed == True,
            ).order_by(ClientScheduleORM.date.desc()).limit(limit).all()

            return [
                {
                    "id": c.id,
                    "date": c.date,
                    "title": c.title or "Corso",
                    "completed": c.completed,
                }
                for c in courses
            ]
        finally:
            db.close()

    def get_client_exercise_history(self, client_id: str, exercise_name: str = None) -> list:
        """Get historical performance data for a client's exercises."""
        from sqlalchemy import func

        db = get_db_session()
        try:
            query = db.query(
                ClientExerciseLogORM.date,
                func.max(ClientExerciseLogORM.weight).label('max_weight'),
                func.sum(ClientExerciseLogORM.reps).label('total_reps'),
                func.count(ClientExerciseLogORM.id).label('sets')
            ).filter(ClientExerciseLogORM.client_id == client_id)

            if exercise_name:
                query = query.filter(ClientExerciseLogORM.exercise_name == exercise_name)

            query = query.group_by(ClientExerciseLogORM.date).order_by(ClientExerciseLogORM.date.asc())

            results = query.all()

            history = []
            for r in results:
                history.append({
                    "date": r.date,
                    "max_weight": r.max_weight,
                    "total_reps": r.total_reps,
                    "sets": r.sets
                })

            return history
        finally:
            db.close()


# Singleton instance
schedule_service = ScheduleService()

def get_schedule_service() -> ScheduleService:
    """Dependency injection helper."""
    return schedule_service
