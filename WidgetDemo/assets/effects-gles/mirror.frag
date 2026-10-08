// name: Mirror World
// description: The picture's left half mirrored onto its right, so every
// description: scene becomes perfectly symmetrical, and faces and places
// description: take on an uncanny look.
// tags: distortion, fun, symmetry

// Which way it is mirrored: 0 left onto right, 1 top onto bottom, 2 both,
// the top left quarter reflected into all four.
const float Mode = 0.0;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    if (Mode == 0.0 || Mode == 2.0)
        uv.x = uv.x < 0.5 ? uv.x : 1.0 - uv.x;
    // Screen y runs upwards, so the top half is the upper one.
    if (Mode == 1.0 || Mode == 2.0)
        uv.y = uv.y > 0.5 ? uv.y : 1.0 - uv.y;

    fragColor = vec4(texture2D(iChannel0, uv).rgb, 1.0);
}
