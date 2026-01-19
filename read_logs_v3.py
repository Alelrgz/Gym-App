def grep_logs(filename, query):
    try:
        with open(filename, 'r') as f:
            for line in f:
                if query in line:
                    print(line.strip())
    except Exception as e:
        print(f"Error reading {filename}: {e}")

if __name__ == "__main__":
    print("--- server.log DEBUG ---")
    grep_logs('server.log', 'DEBUG')
    print("\n--- server_debug.log DEBUG (Last 20) ---")
    # Read last 20 lines matching DEBUG from debug log
    try:
        with open('server_debug.log', 'r') as f:
            lines = [line.strip() for line in f if 'DEBUG' in line]
            for line in lines[-20:]:
                print(line)
    except:
        pass
