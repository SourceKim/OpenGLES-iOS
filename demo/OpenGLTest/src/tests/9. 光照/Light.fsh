varying highp vec3 outNormal; // 输出的法向量
varying highp vec3 outFragmentPosition; // 输出的片段位置

uniform highp vec3 originColor; // 物体的颜色

uniform highp int needLight; // 是否需要光照（光源不需要） If rendering "Lamb", this value is 0; else 1;

uniform highp vec3 lightColor; // 灯的颜色
uniform highp float ambientStrength; // 环境光强度

uniform highp vec3 lightPos; // 灯的位置

uniform highp vec3 eyePos; // 摄像机（眼睛）的位置

uniform highp float specularStrength; // 镜面光强度

void main() {
    
    highp vec3 color;
    
    if (needLight != 0) { // The Object, calculate the final color affected by light
        
        // Ambient
        highp vec3 ambient = ambientStrength * lightColor;
        
        // Diffuse
        highp vec3 norm = normalize(outNormal);
        highp vec3 lightDir = normalize(lightPos - outFragmentPosition);
        
        highp float diff = max(dot(norm, lightDir), 0.0);
        highp vec3 diffuse = diff * lightColor;
        
        // Specular
        highp vec3 eyeDir = normalize(eyePos - outFragmentPosition); // 视线方向
        highp vec3 reflectDir = reflect(-lightDir, norm); // 光线反射的方向
        
        highp float spec = pow(max(dot(eyeDir, reflectDir), 0.0), 32.0);
        highp vec3 specular = specularStrength * spec * lightColor;
        
        
        // Combine all kind of colors
        color = (ambient + diffuse + specular) * originColor;
        
    } else { // The "Lamb",  use originColor
        
        color = originColor;
        
    }
    
    gl_FragColor = vec4(color, 1.0);
    
}
