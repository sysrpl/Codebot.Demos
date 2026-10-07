// name: Tilt-shift Miniature
// description: Makes real scenes look like tiny model sets: a narrow band in
// description: sharp focus, everything above and below it blurred, and the
// description: colours bright like painted toys. Best on wide or high shots.
// tags: photography, lens, blur, miniature, toy

// Where the sharp band lies, from 0 at the bottom to 1 at the top, and how
// tall it is. Model photos are usually sharp a little below the middle.
const float Focus = 0.42;
const float Band = 0.08;

// How far the blur reaches at the top and bottom, in pixels.
const float MostBlur = 12.0;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 pixel = 1.0 / iResolution.xy;
    vec2 uv = fragCoord * pixel;

    // The blur grows steadily away from the band, as a tilted lens's does.
    float away = abs(uv.y - Focus);
    float radius = smoothstep(Band, Band + 0.35, away) * MostBlur;

    // A lens blur: sixteen samples spread evenly over a disc, placed along a
    // spiral turned by the golden angle so none line up.
    vec3 color = vec3(0.0);
    for (int i = 0; i < 16; i++)
    {
        float r = sqrt((float(i) + 0.5) / 16.0) * radius;
        float angle = float(i) * 2.3999632;
        color += texture2D(iChannel0, uv + vec2(cos(angle), sin(angle)) * r * pixel).rgb;
    }
    color /= 16.0;

    // Toys are painted brighter and more boldly than the real world.
    float level = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = vec3(level) + (color - vec3(level)) * 1.45;
    color = clamp((color - 0.5) * 1.12 + 0.52, 0.0, 1.0);

    fragColor = vec4(color, 1.0);
}
