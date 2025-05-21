// HEI$Ttech
// VRLightVolumeProjector
// v1.0.1
// 2025-05-21
// 
// Provides a method to project light volumes onto avatars without the need to customize the avatars shaders.
// Uses Blend One One for additive lighting.

Shader "Light Volume Samples/Light Volume Projector" {
    Properties {
        [HDR] _ProjectorColor ("Projector Color (RGB) & Intensity (A)", Color) = (1,1,1,1)
        _MainTex ("Fallback Texture (Cookie)", 2D) = "white" {}
    }
    SubShader {
        Tags { "Queue"="Transparent-1" "RenderType"="Transparent" }

        Pass {
            Name "FORWARD"
            Tags { "LightMode"="ForwardBase" }

            Cull Off
            ZWrite Off
            ZTest LEqual
            Blend One One

            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Assets/VRCLightVolumes/Shaders/LightVolumes.cginc"

            sampler2D _MainTex;
            float4x4 unity_Projector;
            fixed4 _ProjectorColor;

            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float4 uvProj : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
            };

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.uvProj = mul(unity_Projector, v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                if (_UdonLightVolumeEnabled < 0.5 || _UdonLightVolumeCount < 0.5) {
                    return fixed4(0,0,0,0); 
                }

                fixed4 texCookie = tex2Dproj(_MainTex, UNITY_PROJ_COORD(i.uvProj));

                float3 projectedCoords = i.uvProj.xyz / i.uvProj.w;
                if (projectedCoords.x < 0 || projectedCoords.x > 1 ||
                    projectedCoords.y < 0 || projectedCoords.y > 1 ||
                    projectedCoords.z < 0 || projectedCoords.z > 1) {
                    discard;
                }
                
                float3 L0, L1r, L1g, L1b;
                LightVolumeSH(i.worldPos, L0, L1r, L1g, L1b);

                float3 worldNormal = normalize(i.worldNormal);
                float3 diffuseLight = LightVolumeEvaluate(worldNormal, L0, L1r, L1g, L1b);

                diffuseLight *= _ProjectorColor.a;

                fixed3 finalColor = diffuseLight * _ProjectorColor.rgb;
                
                fixed finalAlpha = texCookie.a;

                return fixed4(finalColor, finalAlpha);
            }
            ENDCG
        }
    }
    Fallback "Legacy Shaders/Transparent/Diffuse"
}