extends Node

# Traditional Bubble Sort implementation
func bubble_sort(array: Array) -> Array:
	var arr = array.duplicate()
	var n = arr.size()
	var swapped = true
	
	# Continue until no swaps occur in a complete pass
	while swapped:
		swapped = false
		
		# Start from index 0 every pass
		for i in range(n - 1):
			# Compare adjacent elements from left to right
			if arr[i] > arr[i + 1]:
				# Swap if out of order
				var temp = arr[i]
				arr[i] = arr[i + 1]
				arr[i + 1] = temp
				swapped = true
	
	return arr

# For demonstration purposes - returns step-by-step process
func bubble_sort_with_steps(array: Array) -> Dictionary:
	var arr = array.duplicate()
	var n = arr.size()
	var swapped = true
	var steps = []
	
	steps.append({
		"step": "initial",
		"array": arr.duplicate(),
		"swapped": false
	})
	
	var pass_count = 0
	
	while swapped:
		swapped = false
		pass_count += 1
		
		for i in range(n - 1):
			var step_data = {
				"step": "compare",
				"pass": pass_count,
				"index": i,
				"array": arr.duplicate(),
				"comparing": [i, i + 1],
				"swapped": false
			}
			
			if arr[i] > arr[i + 1]:
				var temp = arr[i]
				arr[i] = arr[i + 1]
				arr[i + 1] = temp
				swapped = true
				step_data["swapped"] = true
				step_data["array"] = arr.duplicate()
			
			steps.append(step_data)
		
		steps.append({
			"step": "pass_complete",
			"pass": pass_count,
			"array": arr.duplicate(),
			"swapped": swapped
		})
	
	return {
		"sorted_array": arr,
		"steps": steps,
		"total_passes": pass_count
	}
