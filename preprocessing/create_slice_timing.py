
import numpy as np

def generate_slice_timing(n_slices=50, mb_factor=2, TR=1.7, direction="IS", output_file="slice_timing.txt"):
    # Calculate the time increment per slice acquisition
    time_step = TR / (n_slices // mb_factor)
    print(time_step)
    
    # Create slice acquisition order based on interleaved multiband pattern
    odd_slices = [(i + 1, i + (n_slices // mb_factor) + 1) for i in range(0, n_slices // mb_factor, 1) if (i + 1) % 2 != 0]
    even_slices = [(i + 1, i + (n_slices // mb_factor) + 1) for i in range(0, n_slices // mb_factor, 1) if (i + 1) % 2 == 0]
    print(odd_slices)
    print(even_slices)
    
    slice_order = odd_slices + even_slices  # First odd, then even pairs
    
    # Generate slice timing values
    slice_timing = [i * time_step for i in range(len(slice_order))]

    #slice_timing = slice_timing + slice_timing  # Duplicate for both interleaved passes
    
    print(slice_timing)
    
    
    
    # Create a dictionary to store timing for each slice
    slice_timing_dict = {}
    for idx, (slice1, slice2) in enumerate(slice_order):
        slice_timing_dict[slice1] = slice_timing[idx]
        slice_timing_dict[slice2] = slice_timing[idx]
    
    # Sort by slice index
    sorted_timings = [slice_timing_dict[i+1] for i in range(n_slices)]
    
    # Reverse timings if direction is SI
    if direction.upper() == "SI":
        sorted_timings.reverse()
    
    # Save to file
    with open(output_file, "w") as f:
        for timing in sorted_timings:
            f.write(f"{timing:.6f}\n")
    
    print(f"Slice timing file '{output_file}' created successfully.")

# Run the function
generate_slice_timing()
