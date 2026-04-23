# 保持所有 Flutter 插件相关类不被混淆
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.util.** { *; }

# 保持插件包中的所有类和成员
-keep class com.yourcompany.pluginname.** { *; }

# 保持所有实现 FlutterPlugin 的类
-keep class * implements io.flutter.plugin.common.PluginRegistry {
    *;
}

# 保持所有 MethodChannel 相关类
-keep class * extends io.flutter.plugin.common.MethodCall {
    *;
}

# 保持所有 EventChannel 相关类
-keep class * extends io.flutter.plugin.common.EventChannel {
    *;
}

# 保持所有 BasicMessageChannel 相关类
-keep class * extends io.flutter.plugin.common.BasicMessageChannel {
    *;
}

# 保持 Flutter 原生视图相关类
-keep class * extends io.flutter.plugin.platform.PlatformView {
    *;
}

-keep class * extends io.flutter.plugin.platform.PlatformViewFactory {
    *;
}

# 保持所有可能通过反射调用的类
-keepclassmembers class * {
    @io.flutter.plugin.common.MethodCall *;
}

# 保持所有注解
-keepattributes *Annotation*

# 保持泛型信息
-keepattributes Signature

# 保持行号信息（有助于调试）
-keepattributes SourceFile,LineNumberTable

# 保持枚举类型
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# 保持序列化相关的类
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# 保持原生方法
-keepclasseswithmembernames class * {
    native <methods>;
}

# 保持自定义视图的构造函数
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}

-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

# 保持 Parcelable 实现
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}