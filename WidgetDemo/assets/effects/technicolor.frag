// name: Technicolor
// description: The rich, saturated colour of 1950s Technicolor films: deep
// description: reds, lush greens and vivid blues, a little larger than life.
// tags: film, colour, color, grade, vintage, movie

// How far towards the full Technicolor look, 0 none to 1 all.
const float Strength = 0.7;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec3 color = texture2D(iChannel0, fragCoord / iResolution.xy).rgb;

    // Three strip Technicolor filmed red, green and blue on separate strips
    // of black and white film, then printed each in its own dye. Imitated
    // here: each colour is held back wherever either of the other two stands
    // out above it, so every colour comes out purer and deeper, much as the
    // separate dyes did.
    float redOver = color.r - (color.g + color.b) * 0.5;
    float greenOver = color.g - (color.r + color.b) * 0.5;
    float blueOver = color.b - (color.r + color.g) * 0.5;
    vec3 printed = vec3(color.r * (1.0 - greenOver) * (1.0 - blueOver),
                        color.g * (1.0 - redOver) * (1.0 - blueOver),
                        color.b * (1.0 - redOver) * (1.0 - greenOver));
    color = mix(color, printed, Strength);

    // Richer still, a touch warm, and the blacks a little deeper.
    float level = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = vec3(level) + (color - vec3(level)) * 1.25;
    color *= vec3(1.04, 1.0, 0.96);
    color = pow(clamp(color, 0.0, 1.0), vec3(1.08));

    fragColor = vec4(color, 1.0);
}
