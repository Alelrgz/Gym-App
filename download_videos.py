import os
import yt_dlp

def download_video(search_query, filename):
    output_path = os.path.join("static", "videos", filename)
    if os.path.exists(output_path):
        print(f"Video {filename} already exists, skipping.")
        return

    ydl_opts = {
        'format': 'best[ext=mp4]',
        'outtmpl': output_path,
        'noplaylist': True,
        'quiet': True,
    }

    print(f"Downloading {filename}...")
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        try:
            ydl.download([f"ytsearch1:{search_query}"])
            print(f"Successfully downloaded {filename}")
        except Exception as e:
            print(f"Failed to download {filename}: {e}")

if __name__ == "__main__":
    if not os.path.exists(os.path.join("static", "videos")):
        os.makedirs(os.path.join("static", "videos"))

    videos = {
        "InclineDBPress.mp4": "incline dumbbell press exercise demonstration short",
        "SeatedShoulderPress.mp4": "seated dumbbell shoulder press exercise demonstration short",
        "MachineFly.mp4": "machine chest fly exercise demonstration short",
        "LateralRaise.mp4": "dumbbell lateral raise exercise demonstration short",
        "TricepPushdown.mp4": "tricep rope pushdown exercise demonstration short"
    }

    for filename, query in videos.items():
        download_video(query, filename)
