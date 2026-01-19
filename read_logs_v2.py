def grep_logs(filename, query):
    try:
        with open(filename, 'r') as f:
            for line in f:
                if query in line:
                    print(line.strip())
    except Exception as e:
        print(f"Error reading {filename}: {e}")

if __name__ == "__main__":
    print("--- Recent Client Access ---")
    grep_logs('server_debug.log', 'DEBUG: get_client called for')
