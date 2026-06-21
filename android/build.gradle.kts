allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Force tất cả sub-projects (kể cả agora_rtc_engine) dùng NDK 28 đã cài sẵn và Java 17
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            try {
                ext.javaClass.getMethod("setNdkVersion", String::class.java)
                    .invoke(ext, "28.2.13676358")
            } catch (_: Exception) {}

            if (project.name != "app") {
                val android = ext as? com.android.build.gradle.BaseExtension
                android?.compileOptions?.apply {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }

        if (project.name != "app") {
            tasks.withType<JavaCompile>().configureEach {
                sourceCompatibility = "17"
                targetCompatibility = "17"
            }
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
