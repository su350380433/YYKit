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

 @param typeEncoding typeEncoding description
 @return return value description
 */
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

- (instancetype)initWithIvar:(Ivar)ivar {
    if (!ivar) return nil;
    self = [super init];
    _ivar = ivar;
    const char *name = ivar_getName(ivar);
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    }
    _offset = ivar_getOffset(ivar);
    const char *typeEncoding = ivar_getTypeEncoding(ivar);
    if (typeEncoding) {
        _typeEncoding = [NSString stringWithUTF8String:typeEncoding];
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
    const char *name = sel_getName(_sel);
    if (name) {
        // 在所有Runtime 以char *定义的API都被视为UTF-8编码,所以这里用stringWithUTF8String
        _name = [NSString stringWithUTF8String:name];
    }
    const char *typeEncoding = method_getTypeEncoding(method);
    if (typeEncoding) {
        _typeEncoding = [NSString stringWithUTF8String:typeEncoding];
    }
    char *returnType = method_copyReturnType(method);
    if (returnType) {
        // 该参数，暂无作用
        _returnTypeEncoding = [NSString stringWithUTF8String:returnType];
        free(returnType);
    }
    unsigned int argumentCount = method_getNumberOfArguments(method); // 该参数，暂无作用
    if (argumentCount > 0) {  // 这一块暂时无意义
        NSMutableArray *argumentTypes = [NSMutableArray new];
        for (unsigned int i = 0; i < argumentCount; i++) {
            char *argumentType = method_copyArgumentType(method, i);
            NSString *type = argumentType ? [NSString stringWithUTF8String:argumentType] : nil;
            [argumentTypes addObject:type ? type : @""];
            if (argumentType) free(argumentType);
        }
        _argumentTypeEncodings = argumentTypes;
    }
    return self;
}

@end

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
    
    LTEncodingType type = 0;
    unsigned int attrCount;
    objc_property_attribute_t *attrs = property_copyAttributeList(property, &attrCount);
    
    for (unsigned int i = 0; i < attrCount; i++) {
        NSLog(@"attrs[i].name1[0]---%c",attrs[i].name[0]);
        switch (attrs[i].name[0]) { // 或者属性每一个类型编码，见声明属性文档：Declared property type encodings章节
                
            case 'T': { // Type encoding T@"NSString",C,N,V_name
                if (attrs[i].value) {  // attrs[i].value : Foundation Framework  Code; Example: attrs[i].name[0] = T,attrs->value = @? / @"NSString"/ @ / @"NSDate" / Q / @"UIColor"
                    _typeEncoding = [NSString stringWithUTF8String:attrs[i].value]; // NSString
                    
                    type = LTEncodingGetType(attrs[i].value); // attrs[i].value =  @"NSString" 此时传进去的@"NSString" 通过LTEncodingGetType方法获得对应  对应限定符 LTEncodingTypeObject
                    if ((type & LTEncodingTypeMask) == LTEncodingTypeObject) {
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
                type |= LTEncodingTypePropertyReadonly;
            } break;
            case 'C': {
                type |= LTEncodingTypePropertyCopy;
            } break;
            case '&': {
                type |= LTEncodingTypePropertyRetain;
            } break;
            case 'N': {
                type |= LTEncodingTypePropertyNonatomic;
            } break;
            case 'D': {
                type |= LTEncodingTypePropertyDynamic;
            } break;
            case 'W': {
                type |= LTEncodingTypePropertyWeak;
            } break;
            case 'G': {  // For Example：@property(getter=intGetFoo, setter=intSetFoo:) int intSetterGetter;  Save _getter/ _setter
                type |= LTEncodingTypePropertyCustomGetter;
                if (attrs[i].value) {
                    
                    _getter = NSSelectorFromString([NSString stringWithUTF8String:attrs[i].value]);
                }
            } break;
            case 'S': {
                type |= LTEncodingTypePropertyCustomSetter;
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
    Method *methods = class_copyMethodList(cls, &methodCount);
    if (methods) {
        NSMutableDictionary *methodInfos = [NSMutableDictionary new];
        _methodInfos = methodInfos;
        for (unsigned int i = 0; i < methodCount; i++) {
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

- (void)setNeedUpdate {
    _needUpdate = YES;
}

- (BOOL)needUpdate {
    return _needUpdate;
}

+ (instancetype)classInfoWithClass:(Class)cls {
    if (!cls) return nil;
    static CFMutableDictionaryRef classCache;
    static CFMutableDictionaryRef metaCache;
    static dispatch_once_t onceToken;
    static dispatch_semaphore_t lock;
    dispatch_once(&onceToken, ^{
        classCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        metaCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        lock = dispatch_semaphore_create(1);
    });
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    YYClassInfo *info = CFDictionaryGetValue(class_isMetaClass(cls) ? metaCache : classCache, (__bridge const void *)(cls));
    if (info && info->_needUpdate) {
        [info _update];
    }
    dispatch_semaphore_signal(lock);
    if (!info) {
        info = [[YYClassInfo alloc] initWithClass:cls];
        if (info) {
            dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
            CFDictionarySetValue(info.isMeta ? metaCache : classCache, (__bridge const void *)(cls), (__bridge const void *)(info));
            dispatch_semaphore_signal(lock);
        }
    }
    return info;
}

+ (instancetype)classInfoWithClassName:(NSString *)className {
    Class cls = NSClassFromString(className);
    return [self classInfoWithClass:cls];
}

@end
