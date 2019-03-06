//
//  YYClassInfo.m
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 15/5/9.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "YYClassInfo.h"
#import <objc/runtime.h>


/**
 通过指定类型编码字符串，
 返回类型编码字符串中Foundation Framework 编码字符和method encodings编码字符

 从一个不可变的type-Encoding 字符数组 获取type值
 @param typeEncoding  A Type-Encoding string.
 参数 typeEncoding 一个type-Encoding string
 @return The encoding type.
 返回 这个encoding的type值
 @param typeEncoding typeEncoding description
 @return return value description
 */
//C语言函数，返回值为ADEncodingType，接收参数为不可变的字符数组typeEncoding
//字符串就是字符数组
YYEncodingType YYEncodingGetType(const char *typeEncoding) {
    // 转换const限定符
    char *type = (char *)typeEncoding;
    // 传入字符串为NULL，返回未知类型
    if (!type) return YYEncodingTypeUnknown;
    size_t len = strlen(type);
    // 类型编码字符串的长度为空，返回未知类型编码
    if (len == 0) return YYEncodingTypeUnknown;
    // @property (nonatomic(3:property), copy(2:property)) const(0:Qualifier) NSString(1:Foundation Framework ) *title(4);   rT@"NSString",C,N,V_title
    YYEncodingType qualifier = 0;
    bool prefix = true;
    // 可能多个编码字符（多种方法修饰）
    while (prefix) {
        /**  for type qualifiers（方法编码限定符，其中switch对应类型编码文档：）
         Code Meaning
         r    const
         n     in
         N    inout
         o     out
         O    bycopy
         R    byref
         V    oneway
         */
        switch (*type) {
            case 'r': {
                qualifier |= YYEncodingTypeQualifierConst;
                type++;
            } break;
            case 'n': {
                qualifier |= YYEncodingTypeQualifierIn;
                type++;
            } break;
            case 'N': {
                qualifier |= YYEncodingTypeQualifierInout;
                type++;
            } break;
            case 'o': {
                qualifier |= YYEncodingTypeQualifierOut;
                type++;
            } break;
            case 'O': {
                qualifier |= YYEncodingTypeQualifierBycopy;
                type++;
            } break;
                // bycopy 修饰的方法
            case 'R': {
                qualifier |= YYEncodingTypeQualifierByref;
                type++;
            } break;
                // oneway 修饰的方法
            case 'V': {
                qualifier |= YYEncodingTypeQualifierOneway;
                type++;
            } break;
                // 当前字符不再匹配 method encodings编码字符
            default: { prefix = false; } break;
        }
    }
    // 判断类型编码后续字符
    len = strlen(type);
    // 类型编码字符串的长度为空，返回字符串未知类型编码和method encodings限定符编码
    if (len == 0) return YYEncodingTypeUnknown | qualifier;
    
    switch (*type) {
            /** For Foundation Framework
             Code     Meaning
             c        A char
             i        An int
             s        A short
             l
             A long   l is treated as a 32-bit quantity on 64-bit programs.
             q        A long long
             C       An unsigned char
             I       An unsigned int
             S       An unsigned short
             L       An unsigned long
             Q       An unsigned long long
             f       A float
             d       A double
             B       A C++ bool or a C99 _Bool
             v       A void
             *       A character string (char *)
             @       An object (whether statically typed or typed id)
             #       A class object (Class)
             :       A method selector (SEL)
             [array type]  An array
             {name=type...}  A structure
             (name=type...)  A union
             bnum            A bit field of num bits
             ^type           A pointer to type
             ?      An unknown type (among other things, this code is used for function pointers)
             
             */
        case 'v': return YYEncodingTypeVoid | qualifier;
        case 'B': return YYEncodingTypeBool | qualifier;
        case 'c': return YYEncodingTypeInt8 | qualifier;
        case 'C': return YYEncodingTypeUInt8 | qualifier;
        case 's': return YYEncodingTypeInt16 | qualifier;
        case 'S': return YYEncodingTypeUInt16 | qualifier;
        case 'i': return YYEncodingTypeInt32 | qualifier;
        case 'I': return YYEncodingTypeUInt32 | qualifier;
        case 'l': return YYEncodingTypeInt32 | qualifier;
        case 'L': return YYEncodingTypeUInt32 | qualifier;
        case 'q': return YYEncodingTypeInt64 | qualifier;
        case 'Q': return YYEncodingTypeUInt64 | qualifier;
        case 'f': return YYEncodingTypeFloat | qualifier;
        case 'd': return YYEncodingTypeDouble | qualifier;
        case 'D': return YYEncodingTypeLongDouble | qualifier;
        case '#': return YYEncodingTypeClass | qualifier;
        case ':': return YYEncodingTypeSEL | qualifier;
        case '*': return YYEncodingTypeCString | qualifier;
        case '^': return YYEncodingTypePointer | qualifier;
        case '[': return YYEncodingTypeCArray | qualifier;
        case '(': return YYEncodingTypeUnion | qualifier;
        case '{': return YYEncodingTypeStruct | qualifier;
        case '@': {
            if (len == 2 && *(type + 1) == '?')
                return YYEncodingTypeBlock | qualifier;
            else
                return YYEncodingTypeObject | qualifier;
        }
            // 当前字符不再匹配 Foundation Framework 编码字符
        default: return YYEncodingTypeUnknown | qualifier;
    }
}

@implementation YYClassIvarInfo

-(instancetype)initWithIvar:(Ivar)ivar{
    
    if (!ivar) return nil;
    self = [super init];
    _ivar = ivar;
    //    ivar_getName 获取成员变量名，可通过[valueForKeyPath:name]获取属性值
    const char *name = ivar_getName(ivar);
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    }
    //获取成员变量的偏移量,runtime会计算ivar的地址偏移来找ivar的最终地址
    _offset = ivar_getOffset(ivar);
    //获取ivar的成员变量类型编码
    const char *typeEncoding = ivar_getTypeEncoding(ivar);
    if (typeEncoding) {
        //对type string 进行UTF-8编码处理
        _typeEncoding = [NSString stringWithUTF8String:typeEncoding];
        
        //        从一个不可变的type-Encoding 字符数组 获取type值
        _type = YYEncodingGetType(typeEncoding);
    }
    return self;
    
}

@end

@implementation YYClassMethodInfo

- (instancetype)initWithMethod:(Method)method {
    if (!method) return nil;
    self = [super init];
    _method = method;
    _sel = method_getName(method);
    _imp = method_getImplementation(method);
    //    Returns the name of the method specified by a given selector.
    //    通过获得的一个selector返回这个方法的说明名字
    //    @return A C string indicating the name of the selector.
    //    返回一个c string 标示这个selector的name
    //    返回值：值不可变的字符指针name，字符指针通常指向一个字符数组的首地址，字符数组类似于字符串
    const char *name = sel_getName(_sel);
    if (name) {
        // 在所有Runtime 以char *定义的API都被视为UTF-8编码,所以这里用stringWithUTF8String
        _name = [NSString stringWithUTF8String:name];
    }
    //    Returns a string describing a method's parameter and return types.
    //    通过接收的一个方法返回一个string类型描述(OC实现的编码类型)
    //    @return A C string. The string may be \c NULL.
    //    返回一个C string . 这个string 可能是 \c NULL
    //    获取方法的参数和返回值类型
    const char *typeEncoding = method_getTypeEncoding(method);
    if (typeEncoding) {
        _typeEncoding = [NSString stringWithUTF8String:typeEncoding];
    }
    //    Returns a string describing a method's return type.
    //    通过一个方法返回一个string(字符数组)描述（方法的返回值类型的字符串）
    //    @return A C string describing the return type. You must free the string with \c free().
    //    返回一个C string 描述. 你必须释放这个string 使用 \c free()
    //   获取方法的返回值类型的字符串
    char *returnType = method_copyReturnType(method);
    if (returnType) {
        // 该参数，暂无作用
        _returnTypeEncoding = [NSString stringWithUTF8String:returnType];
        free(returnType);
    }
    //     Returns the number of arguments accepted by a method
    //    通过一个方法返回主题采用数字(返回方法的参数的个数)
    //    @return An integer containing the number of arguments accepted by the given method.
    //    返回 一个integer 包含这个主题使用数字通过给予的方法
    //    返回方法的参数的个数
    unsigned int argumentCount = method_getNumberOfArguments(method);
    if (argumentCount > 0) {
        NSMutableArray *argumentTypes = [NSMutableArray new];
        for (unsigned int i = 0; i < argumentCount; i++) {
            //       Returns a string describing a single parameter type of a method.
            //       通过关于一个方法的一个单独的type参数返回一个string描述(获取方法的指定位置参数的类型字符串)
            //       获取方法的指定位置参数的类型字符串
            char *argumentType = method_copyArgumentType(method, i);
            //有值就通过UTF-8编码后获取否则为nil
            NSString *type = argumentType ? [NSString stringWithUTF8String:argumentType] : nil;
            //argumentTypes能否添加type 如果能则添加type,否则添加@""
            //保证绝对有个对象被添加到可变数组
            [argumentTypes addObject:type ? type: @""];
            //如果argumentType有值就释放，加个判断防止释放的是野指针
            if (argumentType) free(argumentType);
        }
        _argumentTypeEncodings = argumentTypes;
    }
    return self;
}

@end
/**
 Property information.
 property 信息
 
 Creates and returns a property info object.
 创建并返回一个property的对象信息
 
 @param property property opaque struct
 参数 property 不透明结构体property
 @return A new object, or nil if an error occurs.
 返回 一个新的对象,发生错误返回nil
 */


@implementation YYClassPropertyInfo

- (instancetype)initWithProperty:(objc_property_t)property {
    if (!property) {
        return nil;
    }
    self = [self init];
    _property = property;
    const char *name = property_getName(property);
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    }
    
    YYEncodingType type = 0;
    unsigned int attrCount;
    objc_property_attribute_t *attrs = property_copyAttributeList(property, &attrCount);
    
    for (unsigned int i = 0; i < attrCount; i++) {
        //name属性的描述 value属性值
        /**
         结构体中的name与Value：
         属性类型  name值：T  value：变化
         编码类型  name值：C(copy) &(strong) W(weak) 空(assign) 等 value：无
         非/原子性 name值：空(atomic) N(Nonatomic)  value：无
         变量名称  name值：V  value：变化
         
         属性描述为 T@"NSString",&,V_str 的 str
         属性的描述：T 值：@"NSString"
         属性的描述：& 值：
         属性的描述：V 值：_str
         
         G为getter方法，S为setter方法
         D为Dynamic(@dynamic ,告诉编译器不自动生成属性的getter、setter方法)
         */
//        NSLog(@"attrs[i].name1[0]---%c",attrs[i].name[0]);
        switch (attrs[i].name[0]) { // 或者属性每一个类型编码，见声明属性文档：Declared property type encodings章节
                
            case 'T': { // Type encoding T@"NSString",C,N,V_name
                if (attrs[i].value) {  // attrs[i].value : Foundation Framework  Code; Example: attrs[i].name[0] = T,attrs->value = @? / @"NSString"/ @ / @"NSDate" / Q / @"UIColor"
                    _typeEncoding = [NSString stringWithUTF8String:attrs[i].value]; // NSString
                    
                    type = YYEncodingGetType(attrs[i].value); // attrs[i].value =  @"NSString" 此时传进去的@"NSString" 通过LTEncodingGetType方法获得对应  对应限定符 YYEncodingTypeObject
                    if ((type & YYEncodingTypeMask) == YYEncodingTypeObject) {
                        size_t len = strlen(attrs[i].value); // @"NSString" 长度则为11
                        if (len > 3) { // 一般属性的类型长度大于3
                            char name[len - 2]; //原来是name[11] ,现在 11 - 2   name[9]
                            name[len - 3] = '\0'; // name[9] = '\0' 设置最后索引为'\0' ，目的是去掉最有一个“
                            memcpy(name, attrs[i].value + 2, len - 3); // 这行代码目的是获得属性名, 猜想：attrs[i].value + 2 = NSString",属性类型和属性名是共享一份内存的，这个方法copy一份内存到name，通过name就可以获得对应的属性定义的类型。
                            _cls = objc_getClass(name); // name所指向的具体来说内存是属性定义的类型 这里通过name  获得int 、NSString
                        }
                    }
                }
            } break;
                // @property (nonatomic(3:property), copy(2:property)) const(0:Qualifier) NSString(1:Foundation Framework ) *title(4); rT@"NSString",C,N,V_title  获得 2 3 4 位置的编码类型
            case 'V': { // Instance variable
                if (attrs[i].value) {
                    _ivarName = [NSString stringWithUTF8String:attrs[i].value];
                }
            } break;
            case 'R': {
                type |=YYEncodingTypePropertyReadonly;
            } break;
            case 'C': {
                type |= YYEncodingTypePropertyCopy;
            } break;
            case '&': {
                type |= YYEncodingTypePropertyRetain;
            } break;
            case 'N': {
                type |= YYEncodingTypePropertyNonatomic;
            } break;
            case 'D': {
                type |= YYEncodingTypePropertyDynamic;
            } break;
            case 'W': {
                type |= YYEncodingTypePropertyWeak;
            } break;
            case 'G': {  // For Example：@property(getter=intGetFoo, setter=intSetFoo:) int intSetterGetter;  Save _getter/ _setter
                type |= YYEncodingTypePropertyCustomGetter;
                if (attrs[i].value) {
                    
                    _getter = NSSelectorFromString([NSString stringWithUTF8String:attrs[i].value]);
                }
            } break;
            case 'S': {
                type |= YYEncodingTypePropertyCustomSetter;
                if (attrs[i].value) {
                    _setter = NSSelectorFromString([NSString stringWithUTF8String:attrs[i].value]);
                }
            } break;
            default: break;
        }
    }
    
    if (attrs) {
        free(attrs);
        attrs = NULL;
    }
    
    _type = type;
    if (_name.length) {
        if (!_getter) {
            _getter = NSSelectorFromString(_name);
        }
        if (!_setter) { // if _setter not nil ,set Function name
            /**
             For Example: name =  _title  从t开始，而且t字母表示为大写（uppercaseString用字符串的大写字母标识）(substringToIndex取索引为1的字符，substringFromIndex:取1~~~~(length - 1) 字符)大写T
             */
            _setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:", [_name substringToIndex:1].uppercaseString, [_name substringFromIndex:1]]);
        }
    }
    return self;
}

@end

@implementation YYClassInfo {
    BOOL _needUpdate;
}

- (instancetype)initWithClass:(Class)cls {
    // 判断参数的合法性
    if (!cls) return nil;
    self = [super init];
    _cls = cls;
    _superCls = class_getSuperclass(cls); // 获得父类
    _isMeta = class_isMetaClass(cls);   // 是否有元组
    if (!_isMeta) {
        _metaCls = objc_getMetaClass(class_getName(cls));   // 获得元组
    }
    _name = NSStringFromClass(cls);  // // 获得类名
    [self _update];  // 更新方法列表、属性列表、成员列表数据
    
    _superClassInfo = [self.class classInfoWithClass:_superCls]; // 递归最上层父亲信息
    return self;
}

- (void)_update {
    _ivarInfos = nil;
    _methodInfos = nil;
    _propertyInfos = nil;
    
    Class cls = self.cls;
    unsigned int methodCount = 0;
    //    Describes the instance methods implemented by a class.
    //    描述这个列子的方法实现通过一个class
    //    @return An array of pointers of type Method describing the instance methods
    //    返回关于列子的方法描述的一个数组指针
    //    数组长度保存在methodCount地址里
    Method *methods = class_copyMethodList(cls, &methodCount);
    if (methods) {
        NSMutableDictionary *methodInfos = [NSMutableDictionary new];
        _methodInfos = methodInfos;
        for (unsigned int i = 0; i < methodCount; i++) {
            //          使用自定义方法,获取一个对象,对象是根据传过来的一个方法创建
            YYClassMethodInfo *info = [[YYClassMethodInfo alloc] initWithMethod:methods[i]];
            if (info.name) methodInfos[info.name] = info;
        }
        free(methods);
    }
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    if (properties) {
        NSMutableDictionary *propertyInfos = [NSMutableDictionary new];
        _propertyInfos = propertyInfos;
        for (unsigned int i = 0; i < propertyCount; i++) {
            YYClassPropertyInfo *info = [[YYClassPropertyInfo alloc] initWithProperty:properties[i]];
            if (info.name) propertyInfos[info.name] = info;
        }
        free(properties);
    }
    //成员变量的操作，与属性的操作区别在于：成员变量{}中声明的, 属性@property声明的
    //属性会有相应的getter方法和setter方法，而成员变量没有，另外，外部访问属性可以用"."来访问，访问成员变量需要用"->"来访问
    
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    if (ivars) {
        NSMutableDictionary *ivarInfos = [NSMutableDictionary new];
        _ivarInfos = ivarInfos;
        for (unsigned int i = 0; i < ivarCount; i++) {
            YYClassIvarInfo *info = [[YYClassIvarInfo alloc] initWithIvar:ivars[i]];
            if (info.name) ivarInfos[info.name] = info;
        }
        free(ivars);
    }
    
    if (!_ivarInfos) _ivarInfos = @{};
    if (!_methodInfos) _methodInfos = @{};
    if (!_propertyInfos) _propertyInfos = @{};
    
    _needUpdate = NO;
}
/**
 If the class is changed (for example: you add a method to this class with
 'class_addMethod()'), you should call this method to refresh the class info cache.
 如果这个Class是改变的(列如: 你通过class_addMethod()添加了一个方法给这个类),你应该告诉这个方法去刷新class信息缓存
 After called this method, `needUpdate` will returns `YES`, and you should call
 'classInfoWithClass' or 'classInfoWithClassName' to get the updated class info.
 被方法告知之后，"needUpdate"应返回"YES",而且你应该告知'classInfoWithClass' or 'classInfoWithClassName'获取这个class更新信息
 */
- (void)setNeedUpdate {
    _needUpdate = YES;
}
/**
 If this method returns `YES`, you should stop using this instance and call
 `classInfoWithClass` or `classInfoWithClassName` to get the updated class info.
 如果这个方法返回"YES",你应该停止使用这个对象并告知`classInfoWithClass` or `classInfoWithClassName` 去获取class更新信息
 @return Whether this class info need update.
 返回 这个class 信息是否需要更新
 */
- (BOOL)needUpdate {
    return _needUpdate;
}
/**
 Get the class info of a specified Class.
 获取一个Class的class信息说明
 
 @discussion This method will cache the class info and super-class info
 at the first access to the Class. This method is thread-safe.
 
 描述 这个方法将缓存这个class信息 和 父类class信息,在第一次进入这个class时
 这个方法是线程安全的
 @param cls A class.
 参数 cls 一个class
 @return A class info, or nil if an error occurs.
 返回 一个Class 信息， 如果发生错误返回Nil
 */
+ (instancetype)classInfoWithClass:(Class)cls {
    // 判断传入值的合法性
    if (!cls) return nil;
    //   NSMutableDictionary的底层，直接使用CFMutableDictionaryRef可提高效率
    //存放对象(NSArray也是一个对象，详情看下方)
    static CFMutableDictionaryRef classCache; // 类缓存器
    static CFMutableDictionaryRef metaCache; // 元组缓存器
    static dispatch_once_t onceToken;
    // 同步信号量
    static dispatch_semaphore_t lock;
    dispatch_once(&onceToken, ^{  // 保证该块代码在线程安全（内部有一个同步锁）只执行一次
        /**
         
         @功能 CFDictionaryCreateMutable创建一个新的词典。
         
         @参数 CFAllocator 分配器应该用于分配CFAllocator字典的内存及其值的存储。这
         参数可能为空，在这种情况下，当前的默认值CFAllocator使用。如果这个引用不是一个有效的cfallocator，其行为是未定义的。
         
         @参数 capacity 暗示值得个数，通过0实现可能忽略这个提示，或者可以使用它来优化各种
         
         @参数 keyCallBacks 指向CFDictionaryKeyCallBacks结构为这本字典使用回调函数初始化在字典中的每一个键，初始化规则太多而且看的有点迷糊就不多说了，毕竟不敢乱说。。
         @参数 valueCallBacks 指向CFDictionaryValueCallBacks结构为这本词典使用回调函数初始化字典中的每一个值
         
         
         操作
         
         */
        classCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        metaCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        /** dispatch_semaphore_create
         创建新的计数信号量的初始值。
         */
        lock = dispatch_semaphore_create(1);
    });
    //    没有资源，会一直触发信号控制
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    //    class_isMetaClass(Class cls)，判断指定类是否是一个元类(元类是类对象的类,如[NSArray array]中的NSArray也是一个对象,NSArray通过元类生成,而元类又是一个对象，元类的类是根源类NSObject,NSObject父类为Nil)
    YYClassInfo *info = CFDictionaryGetValue(class_isMetaClass(cls) ? metaCache : classCache, (__bridge const void *)(cls)); // 判断该类是元组还是类（initWithClass方法中倒数第二行代码有调用classInfoWithClass方法传入的参数是元组，所以这里需要判断数据存入的是类换成年期还是元组缓存器），根据类名从缓存器中取出数据
    if (info && info->_needUpdate) {
        [info _update];
    }
    dispatch_semaphore_signal(lock);
    if (!info) { // 缓存器中没有该类信息，创建一个类信息
        info = [[YYClassInfo alloc] initWithClass:cls];
        if (info) {
            // 首先CFDictionaryRef是线程安全，这里加锁目的是为了保证内部数据的线程安全，所有访问CFDictionaryRef接口都要经过这个 lock
            dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER); // 设置信号量为1，相当于添加同步锁
            // 缓存classInfo
            CFDictionarySetValue(info.isMeta ? metaCache : classCache, (__bridge const void *)(cls), (__bridge const void *)(info));
            
            // 释放锁
            dispatch_semaphore_signal(lock);
        }
    }
    return info;
}

/**
 Get the class info of a specified Class.
 获取一个Class的class信息说明
 
 @discussion This method will cache the class info and super-class info
 at the first access to the Class. This method is thread-safe.
 
 描述 这个方法将缓存这个class信息和父类class 信息在第一次进入这个class时。
 这个方法是线程安全的
 @param className A class name.
 参数 className 一个class name
 @return A class info, or nil if an error occurs.
 返回 一个class info,如果出现错误返回Nil
 */
+ (instancetype)classInfoWithClassName:(NSString *)className {
    Class cls = NSClassFromString(className);
    return [self classInfoWithClass:cls];
}

@end
