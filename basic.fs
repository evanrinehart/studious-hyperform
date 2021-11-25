#version 150

in vec2 uv;
out vec4 outColor;

uniform sampler2D sheet;
uniform vec2 srcXY;
uniform vec2 srcWH;

/* uv
01  11

00  10
*/

// shade a tile by sampling from a texture
// Rect x y (x + w) (y + h)
// uv coords are used straight, no reflection.
// appropriate for showing graphics saved
// to framebuffer i.e. (0,0) at bottom left.

void main() {
  ivec2 sheetWH = textureSize(sheet, 0);
  float sw = float(sheetWH.x);
  float sh = float(sheetWH.y);
  float x = (uv.x * srcWH.x + srcXY.x) / sw;
  float y = (uv.y * srcWH.y + srcXY.y) / sh;
  outColor = texture(sheet, vec2(x,y));
}
