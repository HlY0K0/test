//フレームの描画まで完了したあと、フレームにレンズが被る部分
//スカイボックス等の背景描画はTransparentのタイミングで行われるようで、GrabPassの都合上背景が覆い尽くされていない場合キューはTransparent以上に設定すること
//でないと未初期化の背景が取得されることになる
Shader "Custom/lense2"
{
	Properties{
	}
	
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent+4" }
        LOD 200
        Blend SrcAlpha OneMinusSrcAlpha
		
		ZWrite On
		
		Pass
        {
			Stencil{
				Ref 1
				Comp Equal
			}
			
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#include "UnityCG.cginc"
				
				
				struct appdata {
					float4	vertex : POSITION;
					float3	normal : NORMAL;
				};
				
				struct v2f {
					float4	vertex	: SV_POSITION;
					float3	view	: COLOR1;
					float3	normal	: COLOR2;
				};
				
				v2f vert (appdata v) {
					v2f o;

					o.vertex = UnityObjectToClipPos(v.vertex);
					o.view	= WorldSpaceViewDir(v.vertex);	//正規化しちゃダメ　v2fは線形補間されるため、正規化された結果を入れると空間が歪む
					o.normal	= normalize( UnityObjectToWorldNormal(v.normal) );
					
					return o;
				}
				
				fixed4 frag (v2f i) : SV_Target {
					float3	normal	= normalize(i.normal);
					float3	view	= normalize(i.view);
					
					
					//反射
					float4	reflect_texel	= UNITY_SAMPLE_TEXCUBE( unity_SpecCube0, reflect(-view,normal) );
					
					//疑似フレネルの計算
					//RGB毎にパラメータを変えてコーティングを表現
					float3	f0	= float3( 0.06,0.13,0.08 );	//真正面から見た時の反射率
					float3	fp	= float3( 2.2, 4.25, 3.5 );	//全反射までのカーブの強さを決めるファクター　角度が浅くなると全反射に近づくが、これに差をつけることでグラデーションになる
					float3	fresnel	= f0 + ( 1.0 - f0 ) * pow( 1.0-abs(dot(view,normal)), fp );
					
					
					return	float4( reflect_texel.xyz , (fresnel.r+fresnel.g+fresnel.b)/3.0 );
				}
			ENDCG
        }
    }
}
