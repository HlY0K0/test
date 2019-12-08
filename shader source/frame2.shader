//レンズの非フレーム部分の描画処理が終わったあとフレームを描画する
//スカイボックス等の背景描画はTransparentのタイミングで行われるようで、GrabPassの都合上背景が覆い尽くされていない場合キューはTransparent以上に設定すること
//でないと未初期化の背景が取得されることになる
Shader "Custom/frame2"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
    }
	
    SubShader
    {
        Tags{ "RenderType"="Opaque" "Queue"="Transparent+3" }
        ZWrite On
		LOD 200
		
		Pass{
			Stencil{
				Comp Always
			}
			
			CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex;

            fixed4 frag (v2f_img i) : COLOR
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                return col;
            }
            ENDCG
		}
    }
}
