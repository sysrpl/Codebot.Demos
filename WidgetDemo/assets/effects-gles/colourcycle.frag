// name: Colour Cycling
// description: Psychedelic: every colour in the picture slowly turning round
// description: the rainbow, in waves that roll across the screen, and
// description: brighter, bolder colours than life.
// tags: colour, color, fun, psychedelic, rainbow

// How long the colours take to go all the way round, in seconds.
const float Cycle = 20.0;

// How strongly the colours roll across the screen rather than all turning
// together, 0 for all together.
const float Rolling = 1.2;

const float Tau = 6.2831853;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    float t = mod(iTime, Cycle * 100.0);
    vec3 color = texture2D(iChannel0, uv).rgb;

    // Colour split into brightness and two colour axes, the way television
    // does it (YIQ), so the colour can be turned without the brightness
    // changing.
    float y = dot(color, vec3(0.299, 0.587, 0.114));
    float i = dot(color, vec3(0.596, -0.274, -0.322));
    float q = dot(color, vec3(0.211, -0.523, 0.312));

    // How far round: the time, a wave rolling across the screen, and a
    // little by brightness, so light and dark parts turn apart.
    float angle = t / Cycle * Tau + sin(uv.x * 3.0 + uv.y * 2.0 + t * 0.3) * Rolling + y * 1.5;
    float c = cos(angle), s = sin(angle);
    vec2 turned = vec2(i * c - q * s, i * s + q * c) * 1.4;

    color = vec3(y + 0.956 * turned.x + 0.621 * turned.y,
                 y - 0.272 * turned.x - 0.647 * turned.y,
                 y - 1.106 * turned.x + 1.703 * turned.y);
    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
