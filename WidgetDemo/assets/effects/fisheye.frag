// name: Fisheye
// description: Through a fisheye lens: the middle of the picture bulging out
// description: towards you, the edges squeezed and bent round, with colour
// description: fringes and darkening towards the rim.
// tags: distortion, lens, bulge

// How much the middle bulges, 0 none to nearly 1 for a great deal.
const float Bulge = 0.45;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    float aspect = iResolution.x / iResolution.y;
    vec2 p = (fragCoord / iResolution.xy - 0.5) * vec2(aspect, 1.0);

    // Out from the middle, as a part of the way to the corners.
    float corner = length(vec2(aspect, 1.0) * 0.5);
    float reach = length(p) / corner;

    // The lens magnifies the middle and less and less towards the edge,
    // where it takes in the picture at its own size, so nothing is lost.
    float scale = mix(1.0 - Bulge, 1.0, reach * reach);

    // Glass bends colours slightly differently, most at the edge: red a
    // little further out than green, blue a little further in.
    float fringe = 0.006 * reach * reach;
    vec2 uvRed = p * scale * (1.0 + fringe) / vec2(aspect, 1.0) + 0.5;
    vec2 uvGreen = p * scale / vec2(aspect, 1.0) + 0.5;
    vec2 uvBlue = p * scale * (1.0 - fringe) / vec2(aspect, 1.0) + 0.5;
    vec3 color = vec3(texture2D(iChannel0, uvRed).r,
                      texture2D(iChannel0, uvGreen).g,
                      texture2D(iChannel0, uvBlue).b);

    // Lenses like this lose light towards the rim.
    color *= 1.0 - 0.45 * smoothstep(0.5, 1.0, reach);

    fragColor = vec4(color, 1.0);
}
