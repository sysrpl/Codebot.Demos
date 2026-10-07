// name: Teal and Orange
// description: The modern blockbuster grade: warm colours and skin pushed to
// description: a glowing orange, cool colours and shadows pushed to teal,
// description: with punchy contrast.
// tags: film, colour, color, grade, movie, blockbuster

const vec3 Orange = vec3(1.0, 0.55, 0.2);
const vec3 Teal = vec3(0.0, 0.55, 0.6);

// How hard colours are pushed towards the two, 0 none to 1 fully.
const float Push = 0.45;

float brightness(vec3 color)
{
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec3 color = texture2D(iChannel0, fragCoord / iResolution.xy).rgb;
    float level = brightness(color);

    // Warm or cool: how much redder than blue a colour is. Warm ones take the
    // orange's hue and cool ones the teal's, each at the colour's own
    // brightness, and more so the more strongly warm or cool it was.
    float warmth = clamp((color.r - color.b) * 2.5, -1.0, 1.0);
    vec3 hue = warmth > 0.0 ? Orange : Teal;
    vec3 graded = hue * (level / brightness(hue));
    color = mix(color, graded, abs(warmth) * Push);

    // Split toning: the shadows teal whatever their colour, the highlights
    // warm, as the grade is usually finished.
    color += Teal * 0.12 * (1.0 - smoothstep(0.0, 0.4, level)) * (1.0 - level);
    color += (Orange - 0.5) * 0.08 * smoothstep(0.6, 1.0, level);

    // Punchy: an S curve for contrast, and colours a little stronger.
    color = clamp(color, 0.0, 1.0);
    color = color * color * (3.0 - 2.0 * color) * 0.6 + color * 0.4;
    level = brightness(color);
    color = vec3(level) + (color - vec3(level)) * 1.15;

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
