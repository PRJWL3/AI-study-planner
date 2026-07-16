from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class Subject(BaseModel):
    name: str
    difficulty: str


class StudyRequest(BaseModel):
    subjects: list[Subject]
    hours_per_day: int
    days_left: int


@app.get("/")
def home():
    return {"message": "AI Study Planner Backend Running"}


@app.post("/generate-plan")
def generate_plan(data: StudyRequest):

    # Difficulty Weights
    weights = {
        "hard": 3,
        "medium": 2,
        "easy": 1
    }

    total_weight = 0

    for subject in data.subjects:
        total_weight += weights.get(
            subject.difficulty.lower(), 1
        )

    study_plan = []

    for subject in data.subjects:

        weight = weights.get(
            subject.difficulty.lower(), 1
        )

        allocated_hours = round(
            (weight / total_weight)
            * data.hours_per_day,
            1
        )

        study_plan.append({
            "subject": subject.name,
            "difficulty": subject.difficulty,
            "hours": allocated_hours
        })

    return {
        "study_plan": study_plan,
        "days_left": data.days_left
    }