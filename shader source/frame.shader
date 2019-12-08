//レンズの描画を行う前のステンシル設定
//スカイボックス等の背景描画はTransparentのタイミングで行われるようで、GrabPassの都合上背景が覆い尽くされていない場合キューはTransparent以上に設定すること
//でないと未初期化の背景が取得されることになる
Shader "Custom/frame"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
    }
	
    SubShader
    {
        Tags{ "RenderType"="Transparent" "Queue"="Transparent+1" }
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
		LOD 200
		
		Pass{
			Stencil{
				Ref 1
				Comp Always
				Pass Replace
			}
			
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#include "UnityCG.cginc"
				
				struct appdata{
					float4 vertex : POSITION;
				};
				
				struct v2f{
					float4 vertex : SV_POSITION;
				};
				
				v2f vert (appdata v){
					v2f o;
					o.vertex = UnityObjectToClipPos(v.vertex);
					return o;
				}
				
				fixed4 frag (v2f i) : SV_Target{
					return fixed4(0, 0, 0, 0);
				}
			ENDCG
		}
    }
}
