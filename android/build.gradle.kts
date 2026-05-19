allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Force tất cả sub-projects (kể cả agora_rtc_engine) dùng NDK 28 đã cài sẵn
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            try {
                ext.javaClass.getMethod("setNdkVersion", String::class.java)
                    .invoke(ext, "28.2.13676358")
            } catch (_: Exception) {}
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
