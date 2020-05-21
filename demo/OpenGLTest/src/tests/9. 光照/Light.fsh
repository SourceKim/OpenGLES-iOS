uniform highp vec3 originColor;

uniform highp int needLight; // If rendering "Lamb", this value is 0; else 1;

uniform highp vec3 lightColor;
uniform highp float ambientStrength;

void main() {
    
    if (needLight != 0) { // The Object, calculate the final color affected by light
        
        highp vec3 ambient = ambientStrength * lightColor;
        highp vec3 color = ambient * originColor;
        
        gl_FragColor = vec4(color, 1.0);
        
    } else { // The "Lamb",  use originColor
        
        gl_FragColor = vec4(originColor, 1.0);
        
    }
    
}
