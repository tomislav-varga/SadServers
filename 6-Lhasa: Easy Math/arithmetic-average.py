# script to calculate the arithmetic average of a txt file where each line contains an index and a number
def calculate_arithmetic_average(file_path):
    total = 0
    count = 0
    
    with open(file_path, 'r') as file:
        for line in file:
            parts = line.split()
            if len(parts) == 2:
                try:
                    number = float(parts[1])
                    total += number
                    count += 1
                except ValueError:
                    print(f"Invalid number on line: {line.strip()}")
    
    if count == 0:
        return 0
    
    average = total / count
    return average

def main():
    import sys

    if len(sys.argv) != 2:
        print("Usage: python arithmetic-average.py <file_path>")
        exit(1)

    file_path = sys.argv[1]
    average = calculate_arithmetic_average(file_path)
    print(f"The arithmetic average is: {average}")

if __name__ == "__main__":
    main()

# Test the function with sample data
# Sample data: List of numbers
#1 7.4
#2 0.4
#3 1.6
#4 6.2
#5 7.6
#6 7.7
#7 5.6
#8 4.4
#9 8.0
#10 7.0
#11 3.1
#12 5.1
#13 3.2
#14 0.3
#15 2.2
#16 6.7
#17 0.8
#18 8.3
#19 1.8
#20 9.0
#21 9.2