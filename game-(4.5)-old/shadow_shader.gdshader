shader_type canvas_item;

uniform float value: hint_range(0, 1) = 1;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	COLOR.a = value; 
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
