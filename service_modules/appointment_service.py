"""
Appointment Service - handles trainer availability and 1-on-1 appointment booking.
"""
from .base import (
    HTTPException, json, logging, date, datetime,
    get_db_session
)
from models_orm import TrainerAvailabilityORM, AppointmentORM, UserORM, TrainerScheduleORM, NotificationORM, ClientProfileORM
from models import (
    TrainerAvailability, Appointment, BookAppointmentRequest,
    SetAvailabilityRequest, UpdateAvailabilityRequest,
    CancelAppointmentRequest, AvailableSlot
)
from typing import List, Dict
import uuid
from datetime import timedelta

logger = logging.getLogger("gym_app")


class AppointmentService:
    """Service for managing trainer availability and appointment booking."""

    # --- GYM TRAINERS ---

    def get_gym_trainers(self, client_id: str) -> List[dict]:
        """Get all trainers in the client's gym."""
        db = get_db_session()
        try:
            # Get client's gym from their profile (not UserORM.gym_owner_id)
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
            if not profile or not profile.gym_id:
                return []

            # Get all trainers in the same gym (approved trainers only)
            trainers = db.query(UserORM).filter(
                UserORM.role == "trainer",
                UserORM.gym_owner_id == profile.gym_id,
                UserORM.is_approved == True
            ).all()

            trainer_list = []
            for trainer in trainers:
                # Get trainer's availability count (to show if they have slots set up)
                availability_count = db.query(TrainerAvailabilityORM).filter(
                    TrainerAvailabilityORM.trainer_id == trainer.id
                ).count()

                # Parse specialties from comma-separated string to list
                specialties_list = []
                if trainer.specialties:
                    specialties_list = [s.strip() for s in trainer.specialties.split(",") if s.strip()]

                trainer_list.append({
                    "id": trainer.id,
                    "name": trainer.username,
                    "profile_picture": trainer.profile_picture,
                    "bio": trainer.bio,
                    "specialties": specialties_list,
                    "has_availability": availability_count > 0
                })

            logger.info(f"Found {len(trainer_list)} trainers for client {client_id} in gym {profile.gym_id}")
            return trainer_list

        except Exception as e:
            logger.error(f"Error getting gym trainers: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to get gym trainers: {str(e)}")
        finally:
            db.close()

    # --- TRAINER AVAILABILITY ---

    def set_trainer_availability(self, trainer_id: str, availability: List[SetAvailabilityRequest]) -> dict:
        """Set or update trainer's weekly availability."""
        db = get_db_session()
        try:
            # Clear existing availability for this trainer
            db.query(TrainerAvailabilityORM).filter(
                TrainerAvailabilityORM.trainer_id == trainer_id
            ).delete()

            # Add new availability slots
            for slot in availability:
                availability_slot = TrainerAvailabilityORM(
                    trainer_id=trainer_id,
                    day_of_week=slot.day_of_week,
                    start_time=slot.start_time,
                    end_time=slot.end_time,
                    is_available=True
                )
                db.add(availability_slot)

            db.commit()
            logger.info(f"Updated availability for trainer: {trainer_id}")

            return {"status": "success", "message": "Availability updated successfully"}

        except Exception as e:
            db.rollback()
            logger.error(f"Error setting trainer availability: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to set availability: {str(e)}")
        finally:
            db.close()

    def get_trainer_availability(self, trainer_id: str) -> List[dict]:
        """Get trainer's weekly availability schedule."""
        db = get_db_session()
        try:
            availability_slots = db.query(TrainerAvailabilityORM).filter(
                TrainerAvailabilityORM.trainer_id == trainer_id
            ).order_by(TrainerAvailabilityORM.day_of_week, TrainerAvailabilityORM.start_time).all()

            return [
                {
                    "id": slot.id,
                    "trainer_id": slot.trainer_id,
                    "day_of_week": slot.day_of_week,
                    "start_time": slot.start_time,
                    "end_time": slot.end_time,
                    "is_available": slot.is_available
                }
                for slot in availability_slots
            ]

        finally:
            db.close()

    def get_available_slots(self, trainer_id: str, date_str: str) -> List[dict]:
        """
        Get available time slots for a specific trainer on a specific date.
        Returns list of 1-hour slots that are free.
        """
        db = get_db_session()
        try:
            # Parse date and get day of week (0 = Monday, 6 = Sunday)
            target_date = datetime.fromisoformat(date_str)
            day_of_week = target_date.weekday()

            # Get trainer's availability for this day of week
            availability = db.query(TrainerAvailabilityORM).filter(
                TrainerAvailabilityORM.trainer_id == trainer_id,
                TrainerAvailabilityORM.day_of_week == day_of_week,
                TrainerAvailabilityORM.is_available == True
            ).all()

            if not availability:
                return []

            # Get all booked appointments for this date
            booked_appointments = db.query(AppointmentORM).filter(
                AppointmentORM.trainer_id == trainer_id,
                AppointmentORM.date == date_str,
                AppointmentORM.status.in_(["scheduled", "confirmed"])
            ).all()

            # Also get all trainer calendar events for this date (to avoid conflicts)
            # NOTE: Exclude personal workouts (workout_id is not null) - they are flexible notes
            trainer_events = db.query(TrainerScheduleORM).filter(
                TrainerScheduleORM.trainer_id == trainer_id,
                TrainerScheduleORM.date == date_str,
                TrainerScheduleORM.completed == False,
                TrainerScheduleORM.workout_id == None  # Only block for non-workout events
            ).all()

            # Build list of available slots
            available_slots = []

            for avail_block in availability:
                # Parse start and end times
                start_hour, start_min = map(int, avail_block.start_time.split(':'))
                end_hour, end_min = map(int, avail_block.end_time.split(':'))

                start_time = datetime.combine(target_date.date(), datetime.min.time().replace(hour=start_hour, minute=start_min))
                end_time = datetime.combine(target_date.date(), datetime.min.time().replace(hour=end_hour, minute=end_min))

                # Generate 1-hour slots
                current_time = start_time
                while current_time < end_time:
                    slot_end = current_time + timedelta(hours=1)

                    if slot_end > end_time:
                        break

                    # Check if this slot is already booked by an appointment
                    is_booked = False
                    for appointment in booked_appointments:
                        appt_start_hour, appt_start_min = map(int, appointment.start_time.split(':'))
                        appt_start = datetime.combine(target_date.date(), datetime.min.time().replace(hour=appt_start_hour, minute=appt_start_min))

                        appt_duration = timedelta(minutes=appointment.duration)
                        appt_end = appt_start + appt_duration

                        # Check for overlap
                        if not (slot_end <= appt_start or current_time >= appt_end):
                            is_booked = True
                            break

                    # Also check if slot conflicts with other trainer calendar events
                    if not is_booked:
                        for event in trainer_events:
                            # Parse time in 12-hour format (HH:MM AM/PM)
                            try:
                                event_time = datetime.strptime(event.time, "%I:%M %p")
                                event_start = datetime.combine(target_date.date(), event_time.time())
                                event_duration = timedelta(minutes=event.duration)
                                event_end = event_start + event_duration

                                # Check for overlap
                                if not (slot_end <= event_start or current_time >= event_end):
                                    is_booked = True
                                    break
                            except ValueError:
                                # If time format is invalid, skip this event
                                continue

                    if not is_booked:
                        available_slots.append({
                            "start_time": current_time.strftime("%H:%M"),
                            "end_time": slot_end.strftime("%H:%M"),
                            "available": True
                        })

                    current_time = slot_end

            return available_slots

        except Exception as e:
            logger.error(f"Error getting available slots: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to get available slots: {str(e)}")
        finally:
            db.close()

    # --- APPOINTMENT BOOKING ---

    def book_appointment(self, client_id: str, request: BookAppointmentRequest) -> dict:
        """Book a 1-on-1 appointment with a trainer."""
        db = get_db_session()
        try:
            # Verify trainer exists
            trainer = db.query(UserORM).filter(
                UserORM.id == request.trainer_id,
                UserORM.role == "trainer"
            ).first()

            if not trainer:
                raise HTTPException(status_code=404, detail="Trainer not found")

            # Get client info
            client = db.query(UserORM).filter(UserORM.id == client_id).first()
            client_name = client.username if client else "Client"

            # Check if the slot is available
            available_slots = self.get_available_slots(request.trainer_id, request.date)

            slot_available = False
            for slot in available_slots:
                if slot["start_time"] == request.start_time:
                    slot_available = True
                    break

            if not slot_available:
                raise HTTPException(status_code=400, detail="This time slot is not available")

            # Calculate end time
            start_time_parts = request.start_time.split(":")
            start_datetime = datetime.combine(
                datetime.fromisoformat(request.date).date(),
                datetime.min.time().replace(hour=int(start_time_parts[0]), minute=int(start_time_parts[1]))
            )
            end_datetime = start_datetime + timedelta(minutes=request.duration)
            end_time = end_datetime.strftime("%H:%M")

            # Convert to 12-hour format for trainer calendar
            time_12hr = start_datetime.strftime("%I:%M %p")

            # Create appointment record
            appointment_id = str(uuid.uuid4())
            session_type = request.session_type or "general"
            appointment = AppointmentORM(
                id=appointment_id,
                client_id=client_id,
                trainer_id=request.trainer_id,
                date=request.date,
                start_time=request.start_time,
                end_time=end_time,
                duration=request.duration,
                session_type=session_type,
                notes=request.notes,
                status="scheduled"
            )

            db.add(appointment)

            # Format session type for display
            session_label = session_type.replace("_", " ").title() if session_type else "Training"

            # Also create an entry in the trainer's calendar
            trainer_calendar_entry = TrainerScheduleORM(
                trainer_id=request.trainer_id,
                client_id=client_id,
                appointment_id=appointment_id,
                date=request.date,
                time=time_12hr,
                title=f"{session_label} Session with {client_name}",
                subtitle=request.notes if request.notes else f"{session_label} session",
                type="1on1_appointment",
                duration=request.duration,
                completed=False
            )

            db.add(trainer_calendar_entry)

            # Also create an entry in the CLIENT's calendar so they can see it
            from models_orm import ClientScheduleORM
            trainer_name = trainer.username if trainer else "Trainer"
            client_calendar_entry = ClientScheduleORM(
                client_id=client_id,
                date=request.date,
                title=f"{session_label} Session with {trainer_name}",
                type="appointment",
                completed=False
            )
            db.add(client_calendar_entry)

            # Create notification for trainer
            notification = NotificationORM(
                user_id=request.trainer_id,
                type="appointment_booked",
                title="New Appointment Booked",
                message=f"{client_name} booked a {session_label} session on {request.date} at {time_12hr}",
                data=json.dumps({
                    "appointment_id": appointment_id,
                    "client_id": client_id,
                    "client_name": client_name,
                    "date": request.date,
                    "time": time_12hr,
                    "duration": request.duration,
                    "session_type": session_type
                }),
                read=False,
                created_at=datetime.utcnow().isoformat()
            )
            db.add(notification)

            db.commit()
            db.refresh(appointment)

            logger.info(f"Appointment booked: {appointment_id} - Client: {client_id}, Trainer: {request.trainer_id}")
            logger.info(f"Added to trainer calendar - Entry ID: {trainer_calendar_entry.id}")
            logger.info(f"Notification sent to trainer: {request.trainer_id}")

            return {
                "status": "success",
                "appointment_id": appointment_id,
                "message": "Appointment booked successfully"
            }

        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error booking appointment: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to book appointment: {str(e)}")
        finally:
            db.close()

    def book_appointment_as_trainer(self, trainer_id: str, request: BookAppointmentRequest) -> dict:
        """Book a 1-on-1 appointment for a client (trainer-initiated)."""
        db = get_db_session()
        try:
            # In this case, request.trainer_id actually contains the client_id
            client_id = request.trainer_id

            # Verify client exists
            client = db.query(UserORM).filter(
                UserORM.id == client_id,
                UserORM.role == "client"
            ).first()

            if not client:
                raise HTTPException(status_code=404, detail="Client not found")

            # Get trainer info
            trainer = db.query(UserORM).filter(UserORM.id == trainer_id).first()
            trainer_name = trainer.username if trainer else "Trainer"
            client_name = client.username if client else "Client"

            # Check if the slot is available for the trainer
            available_slots = self.get_available_slots(trainer_id, request.date)

            slot_available = False
            for slot in available_slots:
                if slot["start_time"] == request.start_time:
                    slot_available = True
                    break

            if not slot_available:
                raise HTTPException(status_code=400, detail="This time slot is not available")

            # Calculate end time
            start_time_parts = request.start_time.split(":")
            start_datetime = datetime.combine(
                datetime.fromisoformat(request.date).date(),
                datetime.min.time().replace(hour=int(start_time_parts[0]), minute=int(start_time_parts[1]))
            )
            end_datetime = start_datetime + timedelta(minutes=request.duration)
            end_time = end_datetime.strftime("%H:%M")

            # Convert to 12-hour format for trainer calendar
            time_12hr = start_datetime.strftime("%I:%M %p")

            # Create appointment record
            appointment_id = str(uuid.uuid4())
            session_type = request.session_type or "general"
            session_label = session_type.replace("_", " ").title() if session_type else "Training"

            appointment = AppointmentORM(
                id=appointment_id,
                client_id=client_id,
                trainer_id=trainer_id,
                date=request.date,
                start_time=request.start_time,
                end_time=end_time,
                duration=request.duration,
                session_type=session_type,
                notes=request.notes,
                status="scheduled"
            )

            db.add(appointment)

            # Create entry in trainer's calendar
            trainer_calendar_entry = TrainerScheduleORM(
                trainer_id=trainer_id,
                client_id=client_id,
                appointment_id=appointment_id,
                date=request.date,
                time=time_12hr,
                title=f"{session_label} Session with {client_name}",
                subtitle=request.notes if request.notes else f"{session_label} session",
                type="1on1_appointment",
                duration=request.duration,
                completed=False
            )

            db.add(trainer_calendar_entry)

            # Create entry in client's calendar
            from models_orm import ClientScheduleORM
            client_calendar_entry = ClientScheduleORM(
                client_id=client_id,
                date=request.date,
                title=f"{session_label} Session with {trainer_name}",
                type="appointment",
                completed=False
            )
            db.add(client_calendar_entry)
            logger.info(f"Added client calendar entry for {client_id} on {request.date}")

            # Create notification for CLIENT (not trainer, since trainer is booking)
            notification = NotificationORM(
                user_id=client_id,
                type="appointment_scheduled",
                title="Appointment Scheduled",
                message=f"{trainer_name} scheduled a {session_label} session with you on {request.date} at {time_12hr}",
                data=json.dumps({
                    "appointment_id": appointment_id,
                    "trainer_id": trainer_id,
                    "trainer_name": trainer_name,
                    "date": request.date,
                    "time": time_12hr,
                    "duration": request.duration,
                    "session_type": session_type
                }),
                read=False,
                created_at=datetime.utcnow().isoformat()
            )
            db.add(notification)

            db.commit()
            db.refresh(appointment)
            db.refresh(client_calendar_entry)
            db.refresh(trainer_calendar_entry)

            logger.info(f"Appointment booked by trainer: {appointment_id} - Trainer: {trainer_id}, Client: {client_id}")
            logger.info(f"Client calendar entry ID: {client_calendar_entry.id}, Trainer calendar entry ID: {trainer_calendar_entry.id}")
            logger.info(f"Added to both calendars and notified client")

            return {
                "status": "success",
                "appointment_id": appointment_id,
                "message": f"Appointment scheduled with {client_name}"
            }

        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error booking appointment: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to book appointment: {str(e)}")
        finally:
            db.close()

    def get_client_appointments(self, client_id: str, include_past: bool = False) -> List[dict]:
        """Get all appointments for a client."""
        db = get_db_session()
        try:
            query = db.query(AppointmentORM, UserORM).join(
                UserORM, AppointmentORM.trainer_id == UserORM.id
            ).filter(AppointmentORM.client_id == client_id)

            if not include_past:
                today = datetime.now().date().isoformat()
                query = query.filter(AppointmentORM.date >= today)

            appointments = query.order_by(AppointmentORM.date, AppointmentORM.start_time).all()

            return [
                {
                    "id": appt.id,
                    "trainer_id": appt.trainer_id,
                    "trainer_name": trainer.username,
                    "date": appt.date,
                    "start_time": appt.start_time,
                    "end_time": appt.end_time,
                    "duration": appt.duration,
                    "title": appt.title,
                    "notes": appt.notes,
                    "trainer_notes": appt.trainer_notes,
                    "status": appt.status,
                    "created_at": appt.created_at
                }
                for appt, trainer in appointments
            ]

        finally:
            db.close()

    def get_trainer_appointments(self, trainer_id: str, include_past: bool = False) -> List[dict]:
        """Get all appointments for a trainer."""
        db = get_db_session()
        try:
            query = db.query(AppointmentORM, UserORM).join(
                UserORM, AppointmentORM.client_id == UserORM.id
            ).filter(AppointmentORM.trainer_id == trainer_id)

            if not include_past:
                today = datetime.now().date().isoformat()
                query = query.filter(AppointmentORM.date >= today)

            appointments = query.order_by(AppointmentORM.date, AppointmentORM.start_time).all()

            return [
                {
                    "id": appt.id,
                    "client_id": appt.client_id,
                    "client_name": client.username,
                    "date": appt.date,
                    "start_time": appt.start_time,
                    "end_time": appt.end_time,
                    "duration": appt.duration,
                    "title": appt.title,
                    "notes": appt.notes,
                    "trainer_notes": appt.trainer_notes,
                    "status": appt.status,
                    "created_at": appt.created_at
                }
                for appt, client in appointments
            ]

        finally:
            db.close()

    def cancel_appointment(self, appointment_id: str, user_id: str, request: CancelAppointmentRequest) -> dict:
        """Cancel an appointment."""
        db = get_db_session()
        try:
            appointment = db.query(AppointmentORM).filter(
                AppointmentORM.id == appointment_id
            ).first()

            if not appointment:
                raise HTTPException(status_code=404, detail="Appointment not found")

            # Verify user is either the client or the trainer
            if appointment.client_id != user_id and appointment.trainer_id != user_id:
                raise HTTPException(status_code=403, detail="You don't have permission to cancel this appointment")

            if appointment.status == "canceled":
                raise HTTPException(status_code=400, detail="Appointment is already canceled")

            # Update appointment
            appointment.status = "canceled"
            appointment.canceled_by = user_id
            appointment.canceled_at = datetime.utcnow().isoformat()
            appointment.cancellation_reason = request.cancellation_reason
            appointment.updated_at = datetime.utcnow().isoformat()

            # Remove from trainer calendar
            calendar_entry = db.query(TrainerScheduleORM).filter(
                TrainerScheduleORM.appointment_id == appointment_id
            ).first()

            if calendar_entry:
                db.delete(calendar_entry)
                logger.info(f"Removed trainer calendar entry for canceled appointment: {appointment_id}")

            # Also remove from client calendar
            from models_orm import ClientScheduleORM
            client_calendar_entries = db.query(ClientScheduleORM).filter(
                ClientScheduleORM.client_id == appointment.client_id,
                ClientScheduleORM.date == appointment.date,
                ClientScheduleORM.type == "appointment"
            ).all()

            for entry in client_calendar_entries:
                # Check if this is the appointment entry by matching the title
                if "1-on-1 Session" in entry.title:
                    db.delete(entry)
                    logger.info(f"Removed client calendar entry for canceled appointment: {appointment_id}")
                    break

            db.commit()

            logger.info(f"Appointment canceled: {appointment_id} by user: {user_id}")

            return {"status": "success", "message": "Appointment canceled successfully"}

        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error canceling appointment: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to cancel appointment: {str(e)}")
        finally:
            db.close()

    def complete_appointment(self, appointment_id: str, trainer_id: str, trainer_notes: str = None) -> dict:
        """Mark an appointment as completed (trainer only)."""
        db = get_db_session()
        try:
            appointment = db.query(AppointmentORM).filter(
                AppointmentORM.id == appointment_id,
                AppointmentORM.trainer_id == trainer_id
            ).first()

            if not appointment:
                raise HTTPException(status_code=404, detail="Appointment not found")

            if appointment.status == "completed":
                raise HTTPException(status_code=400, detail="Appointment is already completed")

            appointment.status = "completed"
            appointment.trainer_notes = trainer_notes
            appointment.updated_at = datetime.utcnow().isoformat()

            # Also mark the trainer calendar entry as completed
            calendar_entry = db.query(TrainerScheduleORM).filter(
                TrainerScheduleORM.appointment_id == appointment_id
            ).first()

            if calendar_entry:
                calendar_entry.completed = True
                if trainer_notes:
                    calendar_entry.details = trainer_notes
                logger.info(f"Marked calendar entry as completed for appointment: {appointment_id}")

            db.commit()

            logger.info(f"Appointment completed: {appointment_id}")

            return {"status": "success", "message": "Appointment marked as completed"}

        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error completing appointment: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to complete appointment: {str(e)}")
        finally:
            db.close()

    # --- SESSION TYPES ---

    def get_trainer_session_types(self, trainer_id: str) -> List[str]:
        """Get trainer's specialties as session types for booking."""
        db = get_db_session()
        try:
            trainer = db.query(UserORM).filter(UserORM.id == trainer_id).first()
            if not trainer:
                return []

            # Use trainer's specialties as session types
            if trainer.specialties:
                # Specialties are stored as comma-separated string
                specialties = [s.strip().lower() for s in trainer.specialties.split(",") if s.strip()]
                return specialties
            return []

        finally:
            db.close()

    def set_trainer_session_types(self, trainer_id: str, session_types: List[str]) -> dict:
        """Set trainer's custom session types in their settings."""
        db = get_db_session()
        try:
            trainer = db.query(UserORM).filter(UserORM.id == trainer_id).first()
            if not trainer:
                raise HTTPException(status_code=404, detail="Trainer not found")

            # Parse existing settings or create new
            settings = {}
            if trainer.settings:
                try:
                    settings = json.loads(trainer.settings) if isinstance(trainer.settings, str) else trainer.settings
                except (json.JSONDecodeError, TypeError):
                    settings = {}

            # Update session types
            settings["session_types"] = session_types
            trainer.settings = json.dumps(settings)

            db.commit()
            logger.info(f"Updated session types for trainer {trainer_id}: {session_types}")

            return {"status": "success", "session_types": session_types}

        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error setting session types: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to set session types: {str(e)}")
        finally:
            db.close()


# Singleton instance
appointment_service = AppointmentService()


def get_appointment_service() -> AppointmentService:
    """Dependency injection helper."""
    return appointment_service
