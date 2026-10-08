// name: Infrared Film
// description: Shot on colour infrared film, like Kodak Aerochrome: green
// description: leaves and grass turn hot pink and magenta, skies go a deep
// description: blue-violet, and everything takes on a strange, dreamlike cast.
// tags: photography, film, colour, color, false colour, pink

const float FilmRate = 24.0;

float hash2(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec3 color = texture2D(iChannel0, fragCoord / iResolution.xy).rgb;
    float level = dot(color, vec3(0.2126, 0.7152, 0.0722));

    // A video has no infrared in it, so it is guessed. Living plants reflect
    // infrared far more than any other colour, so green that stands out from
    // the red and blue beside it is taken for plants and made bright in
    // infrared; everything else is about as bright as it looks.
    float plants = smoothstep(0.0, 0.2, color.g - (color.r + color.b) * 0.5);
    float infrared = clamp(level * 0.55 + plants * 0.75, 0.0, 1.0);

    // Aerochrome's layers were shifted along one: infrared printed as red,
    // red as green, and green as blue. Blue light was filtered out. So plants,
    // bright in infrared and green, come out red and blue: pink and magenta.
    vec3 shifted = vec3(infrared, color.r, color.g);

    // Its punchy contrast, and grain.
    shifted = clamp((shifted - 0.5) * 1.15 + 0.5, 0.0, 1.0);
    float frame = mod(floor(iTime * FilmRate), 4096.0);
    shifted += (hash2(fragCoord + vec2(frame * 13.0, frame * 7.0)) - 0.5) * 0.05;

    fragColor = vec4(clamp(shifted, 0.0, 1.0), 1.0);
}
