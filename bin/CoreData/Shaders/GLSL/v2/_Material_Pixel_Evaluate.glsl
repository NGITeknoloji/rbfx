/// _Material_Pixel_Evaluate.glsl
/// Don't include!

#ifdef URHO3D_IS_LIT

#ifdef URHO3D_AMBIENT_PASS
    /// Calculate ambient lighting.
    half3 CalculateAmbientLighting(SurfaceData surfaceData)
    {
    #ifdef URHO3D_PHYSICAL_MATERIAL

        #ifdef URHO3D_BLEND_REFLECTIONS
            half3 linearReflectionColor0 = surfaceData.reflectionColor[0].rgb;
            half3 linearReflectionColor1 = surfaceData.reflectionColor[1].rgb;

            half3 linearReflectionColor = mix(
                linearReflectionColor0, linearReflectionColor1, cReflectionBlendFactor);
        #else
            half3 linearReflectionColor = surfaceData.reflectionColor[0].rgb;
        #endif

        half NoV = abs(dot(surfaceData.normal, surfaceData.eyeVec)) + 1e-5;
        half3 diffuseAndSpecularColor = Indirect_PBR(
            surfaceData.ambientLighting, linearReflectionColor,
            surfaceData.albedo.rgb, surfaceData.specular,
            surfaceData.roughness, NoV);

    #elif defined(URHO3D_REFLECTION_MAPPING)

        #ifdef URHO3D_BLEND_REFLECTIONS
            half3 linearReflectionColor = mix(
                surfaceData.reflectionColor[0].rgb, surfaceData.reflectionColor[1].rgb, cReflectionBlendFactor);
        #else
            half3 linearReflectionColor = surfaceData.reflectionColor[0].rgb;
        #endif

        half3 diffuseAndSpecularColor = Indirect_SimpleReflection(
            surfaceData.ambientLighting, linearReflectionColor, surfaceData.albedo.rgb, surfaceData.reflectionTint);

    #else

        half3 diffuseAndSpecularColor = Indirect_Simple(surfaceData.ambientLighting, surfaceData.albedo.rgb);

    #endif
        return diffuseAndSpecularColor * surfaceData.occlusion + surfaceData.emission;
    }
#endif

#ifdef URHO3D_LIGHT_PASS
    /// Return pixel lighting data for forward rendering.
    DirectLightData GetForwardDirectLightData()
    {
        DirectLightData result;
        result.lightVec = NormalizeLightVector(vLightVec);
    #ifdef URHO3D_LIGHT_CUSTOM_SHAPE
        result.lightColor = GetLightColorFromShape(vShapePos);
    #else
        result.lightColor = GetLightColor(result.lightVec.xyz);
    #endif
    #ifdef URHO3D_HAS_SHADOW
        vec4 shadowUV = ShadowCoordToUV(vShadowPos, vWorldDepth);
        result.shadow = FadeShadow(SampleShadowFiltered(shadowUV), vWorldDepth);
    #endif
        return result;
    }

    /// Calculate lighting from per-pixel light source.
    half3 CalculateDirectLighting(SurfaceData surfaceData)
    {
        DirectLightData lightData = GetForwardDirectLightData();

    #if defined(URHO3D_PHYSICAL_MATERIAL) || URHO3D_SPECULAR > 0
        half3 halfVec = normalize(surfaceData.eyeVec + lightData.lightVec.xyz);
    #endif

    #if defined(URHO3D_SURFACE_VOLUMETRIC)
        half3 lightColor = Direct_Volumetric(lightData.lightColor, surfaceData.albedo.rgb);
    #elif defined(URHO3D_PHYSICAL_MATERIAL)
        half3 lightColor = Direct_PBR(lightData.lightColor, surfaceData.albedo.rgb,
            surfaceData.specular, surfaceData.roughness,
            lightData.lightVec.xyz, surfaceData.normal, surfaceData.eyeVec, halfVec);
    #elif URHO3D_SPECULAR > 0
        half3 lightColor = Direct_SimpleSpecular(lightData.lightColor,
            surfaceData.albedo.rgb, surfaceData.specular,
            lightData.lightVec.xyz, surfaceData.normal, halfVec,
            RoughnessToSpecularPower(surfaceData.roughness), cLightColor.a);
    #else
        half3 lightColor = Direct_Simple(lightData.lightColor,
            surfaceData.albedo.rgb, lightData.lightVec.xyz, surfaceData.normal);
    #endif
        return lightColor * GetDirectLightAttenuation(lightData);
    }
#endif

/// Return color with applied lighting, but without fog.
/// Fills all channels of geometry buffer except destination color.
half3 GetSurfaceColor(SurfaceData surfaceData)
{
#ifdef URHO3D_AMBIENT_PASS
    half3 surfaceColor = CalculateAmbientLighting(surfaceData);
#else
    half3 surfaceColor = vec3(0.0);
#endif

#ifdef URHO3D_GBUFFER_PASS
    gl_FragData[1] = vec4(surfaceData.fogFactor * surfaceData.albedo.rgb, 0.0);
    gl_FragData[2] = vec4(surfaceData.fogFactor * surfaceData.specular, surfaceData.roughness);
    gl_FragData[3] = vec4(surfaceData.normal * 0.5 + 0.5, 0.0);
#elif defined(URHO3D_LIGHT_PASS)
    surfaceColor += CalculateDirectLighting(surfaceData);
#endif
    return surfaceColor;
}

#else // URHO3D_IS_LIT

/// Return color with optionally applied reflection, but without fog.
half3 GetSurfaceColor(SurfaceData surfaceData)
{
    half3 surfaceColor = surfaceData.albedo.rgb;
#ifdef URHO3D_REFLECTION_MAPPING
    surfaceColor += GammaToLightSpace(surfaceData.reflectionTint * surfaceData.reflectionColor.rgb);
#endif

#ifdef URHO3D_GBUFFER_PASS
    gl_FragData[1] = vec4(0.0, 0.0, 0.0, 0.0);
    gl_FragData[2] = vec4(0.0, 0.0, 0.0, 0.0);
    gl_FragData[3] = vec4(0.5, 0.5, 0.5, 0.0);
#endif

    return surfaceColor;
}

#endif // URHO3D_IS_LIT
