// name: Bleach Bypass
// description: The gritty war film look of skipping the bleach when
// description: developing: colour drained out, contrast hard, and a silvery,
// description: metallic sheen over everything.
// tags: film, colour, color, grade, gritty, movie

// How far towards the full effect, 0 none to 1 all.
const float Strength = 0.85;

// How much colour is left, 0 none to 1 all of it.
const float Colour = 0.55;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec3 color = texture2D(iChannel0, fragCoord / iResolution.xy).rgb;
    float level = dot(color, vec3(0.2126, 0.7152, 0.0722));

    // Skipping the bleach leaves the silver in the film on top of the dyes, a
    // black and white picture laid over the colour one. Laid over as in
    // overlay blending: the dark parts of the colour picture multiplied
    // darker, the light parts screened lighter, which is where the hard
    // contrast comes from. The two are blended sharply around the middle.
    vec3 silver = vec3(level);
    vec3 multiplied = 2.0 * color * silver;
    vec3 screened = 1.0 - 2.0 * (1.0 - silver) * (1.0 - color);
    vec3 overlaid = mix(multiplied, screened, clamp((level - 0.45) * 10.0, 0.0, 1.0));
    color = mix(color, overlaid, Strength);

    // Most of the colour drained away, and a faint cold cast.
    level = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = vec3(level) + (color - vec3(level)) * Colour;
    color *= vec3(0.98, 1.0, 1.03);

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
