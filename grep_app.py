def grep_file(filename, query):
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            for i, line in enumerate(f):
                if query in line:
                    print(f"{i+1}: {line.strip()}")
    except Exception as e:
        print(f"Error reading {filename}: {e}")

if __name__ == "__main__":
    print("--- Grepping app.js for openTrainerCalendar ---")
    grep_file('static/js/app.js', 'openTrainerCalendar')
