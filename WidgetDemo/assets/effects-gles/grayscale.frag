// name: Grayscale
// description: The picture in shades of grey, each as bright as its colour
// description: looks to the eye.
// tags: black and white, gray, grey, classic

// The picture in shades of grey, each by how bright its colour looks to the
// eye: the Rec. 709 weights, the ones HD video is made with.

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec3 color = texture2D(iChannel0, fragCoord / iResolution.xy).rgb;
    float grey = dot(color, vec3(0.2126, 0.7152, 0.0722));
    fragColor = vec4(vec3(grey), 1.0);
}
