"""
Trainer-Course Matching Service - intelligently matches trainers to course types based on specialties.
"""
from typing import List, Dict, Optional, Tuple
from .base import (
    HTTPException, logging,
    get_db_session, UserORM, ClientProfileORM, CourseORM
)

logger = logging.getLogger("gym_app")


# Course type to specialty keyword mappings
# Each course type maps to: (primary_keywords, secondary_keywords)
# Primary = direct match (higher score), Secondary = related (lower score)
COURSE_TYPE_SPECIALTY_MAP: Dict[str, Tuple[List[str], List[str]]] = {
    "yoga": (
        ["yoga", "ryt", "vinyasa", "hatha", "ashtanga", "yin"],
        ["flexibility", "mindfulness", "meditation", "stretch", "pilates", "wellness"]
    ),
    "pilates": (
        ["pilates", "mat pilates", "reformer", "classical pilates"],
        ["core", "flexibility", "barre", "yoga", "posture", "rehabilitation"]
    ),
    "hiit": (
        ["hiit", "high intensity", "interval training", "tabata", "circuit"],
        ["cardio", "bootcamp", "crossfit", "functional", "conditioning", "strength"]
    ),
    "dance": (
        ["dance", "zumba", "hip hop", "choreography", "ballet", "jazz"],
        ["cardio", "aerobics", "rhythm", "movement", "salsa", "latin"]
    ),
    "spin": (
        ["spinning", "spin", "cycling", "indoor cycling", "bike"],
        ["cardio", "endurance", "hiit", "interval", "leg strength"]
    ),
    "strength": (
        ["strength", "weight training", "resistance", "bodybuilding", "powerlifting"],
        ["muscle", "conditioning", "functional", "cscs", "nasm", "pes", "crossfit"]
    ),
    "stretch": (
        ["stretching", "flexibility", "mobility", "recovery", "foam rolling"],
        ["yoga", "pilates", "rehabilitation", "injury prevention", "cooldown"]
    ),
    "cardio": (
        ["cardio", "aerobics", "endurance", "running", "treadmill"],
        ["hiit", "dance", "spin", "bootcamp", "conditioning", "interval"]
    )
}

# Certification keywords that indicate expertise
CERTIFICATION_KEYWORDS = [
    "certified", "ryt", "ace", "nasm", "afaa", "issa", "nsca", "cscs",
    "pes", "ces", "cpt", "gfi", "zes", "e-ryt", "200", "500"
]


class TrainerMatchingService:
    """Service for matching trainers to course types based on specialties."""

    def get_trainer_match_score(
        self,
        trainer_specialties: List[str],
        course_type: str
    ) -> Tuple[int, List[str]]:
        """
        Calculate how well a trainer's specialties match a course type.

        Returns:
            Tuple of (score, matching_keywords)
            Score breakdown:
            - 100 points per primary keyword match
            - 30 points per secondary keyword match
            - 10 points per certification keyword
        """
        if course_type not in COURSE_TYPE_SPECIALTY_MAP:
            return (0, [])

        primary_keywords, secondary_keywords = COURSE_TYPE_SPECIALTY_MAP[course_type]

        score = 0
        matches = []

        # Normalize trainer specialties for matching
        normalized_specialties = [s.lower().strip() for s in trainer_specialties]
        specialty_text = " ".join(normalized_specialties)

        # Check primary keywords (high value)
        for keyword in primary_keywords:
            if keyword.lower() in specialty_text:
                score += 100
                matches.append(f"✓ {keyword}")

        # Check secondary keywords (medium value)
        for keyword in secondary_keywords:
            if keyword.lower() in specialty_text:
                score += 30
                matches.append(f"~ {keyword}")

        # Bonus for certifications
        for cert in CERTIFICATION_KEYWORDS:
            if cert.lower() in specialty_text:
                score += 10

        return (score, matches)

    def suggest_trainers_for_course_type(
        self,
        course_type: str,
        gym_id: str,
        limit: int = 5
    ) -> List[Dict]:
        """
        Suggest the best trainers for a specific course type within a gym.

        Args:
            course_type: The type of course (yoga, pilates, hiit, etc.)
            gym_id: The gym owner's ID
            limit: Maximum number of suggestions

        Returns:
            List of trainer suggestions with match scores and details
        """
        db = get_db_session()
        try:
            # Get all approved trainers in this gym
            trainers = db.query(UserORM).filter(
                UserORM.role == "trainer",
                UserORM.gym_owner_id == gym_id,
                UserORM.is_approved == True
            ).all()

            suggestions = []

            for trainer in trainers:
                # Parse specialties
                specialties_list = []
                if trainer.specialties:
                    specialties_list = [s.strip() for s in trainer.specialties.split(",") if s.strip()]

                # Calculate match score
                score, matches = self.get_trainer_match_score(specialties_list, course_type)

                # Get client count (lower = more availability)
                client_count = db.query(ClientProfileORM).filter(
                    ClientProfileORM.trainer_id == trainer.id
                ).count()

                # Get existing courses of this type
                existing_courses = db.query(CourseORM).filter(
                    CourseORM.owner_id == trainer.id,
                    CourseORM.course_type == course_type
                ).count()

                # Bonus for already teaching this type (experience)
                if existing_courses > 0:
                    score += 50 * min(existing_courses, 3)  # Cap bonus at 3 courses
                    matches.append(f"📚 {existing_courses} existing {course_type} course(s)")

                suggestions.append({
                    "trainer_id": trainer.id,
                    "trainer_name": trainer.username,
                    "profile_picture": trainer.profile_picture,
                    "bio": trainer.bio,
                    "specialties": specialties_list,
                    "match_score": score,
                    "match_reasons": matches,
                    "client_count": client_count,
                    "existing_courses_of_type": existing_courses,
                    "recommendation": self._get_recommendation_label(score)
                })

            # Sort by score (highest first), then by client count (lowest first for availability)
            suggestions.sort(key=lambda x: (-x["match_score"], x["client_count"]))

            return suggestions[:limit]

        finally:
            db.close()

    def suggest_trainers_for_all_course_types(self, gym_id: str) -> Dict[str, List[Dict]]:
        """
        Get trainer suggestions for all course types.

        Returns:
            Dictionary mapping course types to trainer suggestions
        """
        result = {}

        for course_type in COURSE_TYPE_SPECIALTY_MAP.keys():
            result[course_type] = self.suggest_trainers_for_course_type(
                course_type, gym_id, limit=3
            )

        return result

    def find_best_trainer_for_course(
        self,
        course_type: str,
        gym_id: str
    ) -> Optional[Dict]:
        """
        Find the single best trainer for a course type.

        Returns:
            The best matching trainer or None if no trainers available
        """
        suggestions = self.suggest_trainers_for_course_type(course_type, gym_id, limit=1)
        return suggestions[0] if suggestions else None

    def get_trainer_course_recommendations(self, trainer_id: str) -> List[Dict]:
        """
        Get course type recommendations for a specific trainer based on their specialties.

        Returns:
            List of course types with match scores, ordered by best fit
        """
        db = get_db_session()
        try:
            trainer = db.query(UserORM).filter(UserORM.id == trainer_id).first()
            if not trainer:
                return []

            specialties_list = []
            if trainer.specialties:
                specialties_list = [s.strip() for s in trainer.specialties.split(",") if s.strip()]

            recommendations = []

            for course_type in COURSE_TYPE_SPECIALTY_MAP.keys():
                score, matches = self.get_trainer_match_score(specialties_list, course_type)

                # Get existing courses of this type
                existing = db.query(CourseORM).filter(
                    CourseORM.owner_id == trainer_id,
                    CourseORM.course_type == course_type
                ).count()

                recommendations.append({
                    "course_type": course_type,
                    "match_score": score,
                    "match_reasons": matches,
                    "already_teaching": existing,
                    "recommendation": self._get_recommendation_label(score)
                })

            # Sort by score (highest first)
            recommendations.sort(key=lambda x: -x["match_score"])

            return recommendations

        finally:
            db.close()

    def get_unassigned_course_types(self, gym_id: str) -> List[Dict]:
        """
        Find course types that don't have any courses in the gym yet.
        Useful for identifying gaps in the gym's offerings.

        Returns:
            List of unassigned course types with suggested trainers
        """
        db = get_db_session()
        try:
            # Get all course types currently offered at this gym
            existing_types = db.query(CourseORM.course_type).filter(
                CourseORM.gym_id == gym_id,
                CourseORM.course_type != None
            ).distinct().all()

            existing_set = {t[0] for t in existing_types if t[0]}

            unassigned = []
            for course_type in COURSE_TYPE_SPECIALTY_MAP.keys():
                if course_type not in existing_set:
                    best_trainer = self.find_best_trainer_for_course(course_type, gym_id)
                    unassigned.append({
                        "course_type": course_type,
                        "status": "not_offered",
                        "suggested_trainer": best_trainer
                    })

            return unassigned

        finally:
            db.close()

    def _get_recommendation_label(self, score: int) -> str:
        """Convert match score to a recommendation label."""
        if score >= 150:
            return "Excellent Match"
        elif score >= 100:
            return "Strong Match"
        elif score >= 50:
            return "Good Match"
        elif score > 0:
            return "Partial Match"
        else:
            return "No Match"


# Singleton instance
trainer_matching_service = TrainerMatchingService()


def get_trainer_matching_service() -> TrainerMatchingService:
    """Dependency injection helper."""
    return trainer_matching_service
