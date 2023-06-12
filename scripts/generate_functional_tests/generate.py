'''
    Generate a CSV file containing all combinations of inputs and regexes from inputs_filename and 
    regexes_filename, and the result of the regexes applied to the inputs. The compiled regexes and
    the output CSV file is ready to be used by AXI_top_tb_multiple_tests_from_csv.sv
'''

import os
import re
import csv
import sys

COMPILED_REGEXES_DIR = "compiled_regexes"

# Get the path of the script
script_path = os.path.dirname(os.path.abspath(__file__))

# Include re2compiler
sys.path.append(os.path.join(script_path, "..", "..", "cicero_compiler"))
import re2compiler

if len(sys.argv) != 4:
    print("Usage: python generate.py <inputs_filename> <regexes_filename> <outdir_name>")
    sys.exit(1)

input_path = sys.argv[1]
regex_path = sys.argv[2]
directory_path = sys.argv[3]


# Read in the input and regex files
with open(input_path, "r") as input_file:
    inputs = input_file.read().splitlines()

with open(regex_path, "r") as regex_file:
    regexes = regex_file.read().splitlines()

# Check if the directory exists
if not os.path.exists(directory_path):
    # Create the directory if it does not exist
    os.makedirs(directory_path)

# Compile the regexes and write them to separate files
compiled_regexes = []
for i, regex_str in enumerate(regexes):
    compiled_regex = re2compiler.compile(data=regex_str)
    compiled_regex_path = os.path.join(script_path, COMPILED_REGEXES_DIR, f"regex_{i}.txt")
    with open(compiled_regex_path, "w") as compiled_regex_file:
        compiled_regex_file.write(compiled_regex)
    compiled_regexes.append(compiled_regex_path)

# Open the CSV file for writing
csv_path = os.path.join(script_path, "test_data.csv")
with open(csv_path, "w", newline="") as csv_file:
    writer = csv.writer(csv_file)

    # Write the header row
    writer.writerow(["input", "regex_file", "output"])

    # Loop through each combination of input and regex
    for input_str in inputs:
        for i, regex_str in enumerate(regexes):
            # Compile the regex
            regex = re.compile(regex_str)

            # Test the input against the regex
            if regex.search(input_str):
                output_str = "true"
            else:
                output_str = "false"

            # Write the row to the CSV file
            writer.writerow([input_str, f"regex_{i}.txt", output_str])