//メガネフレームを描画は行わず、ステンシルだけ設定したあと、フレームに被らない部分のレンズを描画
//スカイボックス等の背景描画はTransparentのタイミングで行われるようで、GrabPassの都合上背景が覆い尽くされていない場合キューはTransparent以上に設定すること
//でないと未初期化の背景が取得されることになる
Shader "Custom/lense"
{
	Properties{
		_Diopter ("Diopter",Range(0.0,0.015))	= 0.01	//レンズの度数　…と言っても現実の眼鏡の度数とは対応しない　歪み効果の強度としての数値
	}
	
    SubShader
    {
        Tags { "Queue"="Transparent+2" }
        LOD 200
		
		//ここまでの描画結果の捕捉
		GrabPass{}
		
		ZWrite On
		
		Pass
        {
			Stencil{
				Ref 1
				Comp NotEqual
			}
			
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#include "UnityCG.cginc"
				
				//vecをaxisを回転軸としてangleラジアン回転させる関数
				float3 RotAboutAxis(float3 vec,float3 axis, float angle) {
					float3 a = normalize(axis);
					float s = sin(angle);
					float c = cos(angle);
					float r = 1.0 - c;
					float3x3	m	= float3x3(
						a.x * a.x * r + c, a.y * a.x * r + a.z * s, a.z * a.x * r - a.y * s,
						a.x * a.y * r - a.z * s, a.y * a.y * r + c, a.z * a.y * r + a.x * s,
						a.x * a.z * r + a.y * s, a.y * a.z * r - a.x * s, a.z * a.z * r + c
					);
					return	mul(vec,m);
				}
				
				
				sampler2D _GrabTexture;
				
				uniform	float	_Diopter;
				
				
				struct appdata {
					float4	vertex : POSITION;
					float3	normal : NORMAL;
				};
				
				struct v2f {
					float4	vertex	: SV_POSITION;
					float4	pos	: COLOR0;
					float3	view	: COLOR1;
					float3	normal	: COLOR2;
					float3	normal_c	: COLOR3;
				};
				
				v2f vert (appdata v) {
					v2f o;

					o.vertex = UnityObjectToClipPos(v.vertex);
					o.pos	= ComputeScreenPos(o.vertex);	//フラグメントシェーダの描画位置を把握するための情報
					o.view	= WorldSpaceViewDir(v.vertex);	//正規化しちゃダメ　v2fは線形補間されるため、正規化された結果を入れると空間が歪む
					o.normal	= normalize( UnityObjectToWorldNormal(v.normal) );
					
					//カメラ空間における法線ベクトルの向き
					//視線ベクトルに対する面の向きとは厳密には違うため、そのまま使うとちょっと違和感が出る…)
					o.normal_c	= mul(v.normal, UNITY_MATRIX_T_MV);
					//そこでカメラ空間における法線の向きを、視線ベクトルをZ軸とした空間に変換する
					//視線ベクトルとカメラの向き（カメラ空間Z軸）とのズレを逆手に、その角度の差を用いて視線ベクトルがZ軸となる様に回転させた時に、法線ベクトルがどの様に見えるかを計算する…というアプローチ
					//本当はフラグメントシェーダ側でやった方が誤差が少ないが、頂点シェーダで計算・補間しても実用上問題は出にくいと思う（グーローシェーディング的誤差は多少出る）
					float3	cam;	//カメラ空間の各軸
					cam.x	= dot( o.view, UNITY_MATRIX_V[0].xyz );
					cam.y	= dot( o.view, UNITY_MATRIX_V[1].xyz );
					cam.z	= dot( o.view,-UNITY_MATRIX_V[2].xyz );
					cam	= normalize(cam);
					//カメラ空間における視線ベクトルとカメラ空間Z軸との外積で回転軸を計算
					float3	rot_axis	= cross( -cam, float3(0.0,0.0,-1.0) );
					//回転角を求める
					float	angle	= acos(-cam.z);
					//回転　上の方で定義した関数
					o.normal_c	= RotAboutAxis( o.normal_c, rot_axis, angle );
					
					
					return o;
				}
				
				fixed4 frag (v2f i) : SV_Target {
					float3	normal	= normalize(i.normal);
					float3	view	= normalize(i.view);
					float3	normal_c	= normalize(i.normal_c);
					
					
					//屈折
					//レンズの度と、ビューベクトルとレンズの向きの違い（カメラ空間での法線のZ値）から像の歪みを決定
					//レンズ正面～斜めから見ると収縮、レンズ真横から見ると若干拡大　になる感じで調整(現実の光学現象とは違う)
					float	distortion	= -_Diopter*(-0.5+normal_c.z);
						//FoVによって効果量が変わってしまうので対策
						float	FoV	= atan(UNITY_MATRIX_P[1][1])*2.0/3.1416;
						distortion	= distortion/(1.0+1.0/FoV);
					//カメラ空間での法線ベクトル方向にズラしてテクセルを拾う
					float4	refract_texel	= tex2Dproj(_GrabTexture, float4( i.pos.xyz + normal_c*distortion, i.pos.w ) );
					//float4	refract_texel	= tex2Dproj(_GrabTexture, float4( i.pos.xyz - 3.0*normal_c*distortion, i.pos.w ) );	//unityのwebglビルドの場合　unityのバグなのか上記だとうまく行かない　OpenGLとDirectXの空間表現の違いからくるものかも？
					
					//反射
					float4	reflect_texel	= UNITY_SAMPLE_TEXCUBE( unity_SpecCube0, reflect(-view,normal) );
					
					//疑似フレネルの計算
					//RGB毎にパラメータを変えてコーティングを表現
					float3	f0	= float3( 0.06,0.13,0.08 );	//真正面から見た時の反射率
					float3	fp	= float3( 2.2, 4.25, 3.5 );	//全反射までのカーブの強さを決めるファクター　角度が浅くなると全反射に近づくが、これに差をつけることでグラデーションになる
					float3	fresnel	= f0 + ( 1.0 - f0 ) * pow( 1.0-abs(normal_c.z), fp );	//ビューベクトル空間での法線が既知であるならばそのZ成分を用いて視線と面の角度が計算できる
					//float3	fresnel	= f0 + ( 1.0 - f0 ) * pow( 1.0-abs(dot(view,normal)), fp );	//しっかりワールド空間でフレネルを計算する場合
					
					
					return	float4( refract_texel.xyz*(1.0-(fresnel.r+fresnel.g+fresnel.b)/3.0) + reflect_texel*fresnel , 1.0 );
				}
			ENDCG
        }
    }
}
