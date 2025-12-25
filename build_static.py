from jinja2 import Environment, FileSystemLoader
import os
import shutil

def build():
    env = Environment(loader=FileSystemLoader("templates"))
    
    # Define pages to build
    pages = [
        {"filename": "index.html", "template": "client.html", "role": "client", "mode": "dashboard"},
        {"filename": "client.html", "template": "client.html", "role": "client", "mode": "dashboard"},
        {"filename": "client_leaderboard.html", "template": "client.html", "role": "client", "mode": "leaderboard"},
        {"filename": "client_progress.html", "template": "client.html", "role": "client", "mode": "progress"},
        {"filename": "trainer.html", "template": "trainer.html", "role": "trainer", "mode": "dashboard"},
        {"filename": "owner.html", "template": "owner.html", "role": "owner", "mode": "dashboard"},
        {"filename": "workout.html", "template": "workout.html", "role": "client", "mode": "workout"},
    ]

    # Ensure www directory exists
    if not os.path.exists("www"):
        os.makedirs("www")

    for page in pages:
        template = env.get_template(page["template"])
        context = {
            "gym_id": "iron_gym",
            "role": page["role"],
            "mode": page["mode"],
            "static_build": True # Flag to change links in base.html
        }
        html_content = template.render(context)
        
        with open(f"www/{page['filename']}", "w", encoding="utf-8") as f:
            f.write(html_content)
        print(f"Generated {page['filename']}")

    # Copy static assets
    if os.path.exists("static"):
        if os.path.exists("www/static"):
            shutil.rmtree("www/static")
        shutil.copytree("static", "www/static")
        print("Copied static assets")

if __name__ == "__main__":
    build()
