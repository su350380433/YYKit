//
//  NSObject+YYModel.m
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 15/5/10.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "NSObject+YYModel.h"
#import "YYClassInfo.h"
#import <objc/message.h>

/**
 attribute((always_inline))强制内联，所有加了attribute((always_inline))的函数在被调用时不会被编译成函数调用而是直接扩展到调用函数体内
 所以force_inline修饰的方法被执行时，不会跳到方法内部执行，而是将方法内部的代码放到调用者内容去执行
 如force_inline修饰的方法a，在方法b中调用不会跳到a中而是将a中代码放到b中直接执行
 需要注意的是对于#define force_inline __inline__ __attribute__((always_inline))而言
 force_inline 指的是 __inline__ __attribute__((always_inline))
 而并不是单独的attribute((always_inline))
 */
#define force_inline __inline__ __attribute__((always_inline))


/// Foundation Class Type 创建Class Type
typedef NS_ENUM (NSUInteger, YYEncodingNSType) {
    YYEncodingTypeNSUnknown = 0,
    YYEncodingTypeNSString,
    YYEncodingTypeNSMutableString,
    YYEncodingTypeNSValue,
    YYEncodingTypeNSNumber,
    YYEncodingTypeNSDecimalNumber,
    YYEncodingTypeNSData,
    YYEncodingTypeNSMutableData,
    YYEncodingTypeNSDate,
    YYEncodingTypeNSURL,
    YYEncodingTypeNSArray,
    YYEncodingTypeNSMutableArray,
    YYEncodingTypeNSDictionary,
    YYEncodingTypeNSMutableDictionary,
    YYEncodingTypeNSSet,
    YYEncodingTypeNSMutableSet,
};

/// Get the Foundation class type from property info.
/**
 通过property信息获取创建者的class type
 
 isSubclassOfClass: 从自身开始，它沿着类的层次结构，在每个等级与目标类逐一进行比较。
 如果发现一个相匹配的对象，返回YES。如果它从类的层次结构自顶向下没有发现符合的对象，返回NO
 
 方法意思为：静态的force_inline修饰的返回值为ADEncodingNSType的方法ADClassGetNSType其所需参数为(Class cls)
 */
static force_inline YYEncodingNSType YYClassGetNSType(Class cls) {
    if (!cls) return YYEncodingTypeNSUnknown;
    if ([cls isSubclassOfClass:[NSMutableString class]]) return YYEncodingTypeNSMutableString;
    if ([cls isSubclassOfClass:[NSString class]]) return YYEncodingTypeNSString;
    if ([cls isSubclassOfClass:[NSDecimalNumber class]]) return YYEncodingTypeNSDecimalNumber;
    if ([cls isSubclassOfClass:[NSNumber class]]) return YYEncodingTypeNSNumber;
    if ([cls isSubclassOfClass:[NSValue class]]) return YYEncodingTypeNSValue;
    if ([cls isSubclassOfClass:[NSMutableData class]]) return YYEncodingTypeNSMutableData;
    if ([cls isSubclassOfClass:[NSData class]]) return YYEncodingTypeNSData;
    if ([cls isSubclassOfClass:[NSDate class]]) return YYEncodingTypeNSDate;
    if ([cls isSubclassOfClass:[NSURL class]]) return YYEncodingTypeNSURL;
    if ([cls isSubclassOfClass:[NSMutableArray class]]) return YYEncodingTypeNSMutableArray;
    if ([cls isSubclassOfClass:[NSArray class]]) return YYEncodingTypeNSArray;
    if ([cls isSubclassOfClass:[NSMutableDictionary class]]) return YYEncodingTypeNSMutableDictionary;
    if ([cls isSubclassOfClass:[NSDictionary class]]) return YYEncodingTypeNSDictionary;
    if ([cls isSubclassOfClass:[NSMutableSet class]]) return YYEncodingTypeNSMutableSet;
    if ([cls isSubclassOfClass:[NSSet class]]) return YYEncodingTypeNSSet;
    return YYEncodingTypeNSUnknown;
}

/// Whether the type is c number.
//这个类型是否是C类型
static force_inline BOOL YYEncodingTypeIsCNumber(YYEncodingType type) {
    switch (type & YYEncodingTypeMask) {
        case YYEncodingTypeBool:
        case YYEncodingTypeInt8:
        case YYEncodingTypeUInt8:
        case YYEncodingTypeInt16:
        case YYEncodingTypeUInt16:
        case YYEncodingTypeInt32:
        case YYEncodingTypeUInt32:
        case YYEncodingTypeInt64:
        case YYEncodingTypeUInt64:
        case YYEncodingTypeFloat:
        case YYEncodingTypeDouble:
        case YYEncodingTypeLongDouble: return YES;
        default: return NO;
    }
}



/// Parse a number value from 'id'.
//（1）id类型对象 -》 NSNumber对象 (2) id类型对象 -》NSString类型对象 -》NSNumber类型对象
/**通过id分析出一个数值__unsafe_unretained 和assign类似，但是它适用于对象类型，当目标被摧毁时，属性值不会自动清空（unsafe,不安全 unretained引用计数不加一）*/
static force_inline NSNumber *YYNSNumberCreateFromID(__unsafe_unretained id value) {
    static NSCharacterSet *dot;//字符串处理工具类
    static NSDictionary *dic;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ // 传入的值属性格式1对其进行处理
        //字符集
        dot = [NSCharacterSet characterSetWithRange:NSMakeRange('.', 1)];
        NSLog(@"%s dot = %@",__FUNCTION__, dot);
        // KEY-Value，一些特定格式字典的转换
        dic = @{@"TRUE" :   @(YES),
                @"True" :   @(YES),
                @"true" :   @(YES),
                @"FALSE" :  @(NO),
                @"False" :  @(NO),
                @"false" :  @(NO),
                @"YES" :    @(YES),
                @"Yes" :    @(YES),
                @"yes" :    @(YES),
                @"NO" :     @(NO),
                @"No" :     @(NO),
                @"no" :     @(NO),
                @"NIL" :    (id)kCFNull,
                @"Nil" :    (id)kCFNull,
                @"nil" :    (id)kCFNull,
                @"NULL" :   (id)kCFNull,
                @"Null" :   (id)kCFNull,
                @"null" :   (id)kCFNull,
                @"(NULL)" : (id)kCFNull,
                @"(Null)" : (id)kCFNull,
                @"(null)" : (id)kCFNull,
                @"<NULL>" : (id)kCFNull,
                @"<Null>" : (id)kCFNull,
                @"<null>" : (id)kCFNull};
    });
    // 判断参数属于格式1，直接返回nil
    if (!value || value == (id)kCFNull) return nil;
    // 判断参数类型是否标识数字类型NSNumber，属于格式2，无需处理直接返回值
    if ([value isKindOfClass:[NSNumber class]]) return value;
    // 判断参数是表示字符串NSString
    if ([value isKindOfClass:[NSString class]]) {
        NSNumber *num = dic[value];//如果是特殊格式里面的值，就转换对应的，如false->@(NO)
        if (num) {
            if (num == (id)kCFNull) return nil;
            return num;
        }
        // 如果传入的value值是5788.57,  rangeOfCharacterFromSet查找字符串是否包含 `.`字符
        if ([(NSString *)value rangeOfCharacterFromSet:dot].location != NSNotFound) {
            const char *cstring = ((NSString *)value).UTF8String; // 因为要调用atof方法所以将value的类型转换为UTF-8类型
            if (!cstring) return nil;
            double num = atof(cstring); // double atof(const char *nptr); 将数字从NSString转化为double
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        } else { // value传入的值是5788转换为NSNumber数字类型
            const char *cstring = ((NSString *)value).UTF8String;
            if (!cstring) return nil;
            return @(atoll(cstring));  //  long long atoll(const char *nptr); 把字符串转换成长长整型数（64位）
        }
    }
    return nil;
}

/// Parse string to date. 把string转换成时间格式类型
//1、通过单例模式构造一个带有时间格式化的block数组（以sting.length 长度为依据区分存入值），
static force_inline NSDate *YYNSDateFromString(__unsafe_unretained NSString *string) {
    typedef NSDate* (^YYNSDateParseBlock)(NSString *string);
#define kParserNum 34 // 日期字符串的最大长度,实际
    // 保存对应长度长度日期字符串解析的Block数组,
    //设置数组内值都为0，使用静态来保存解析成NSDate的Block并且设置对应日期字符串长度
    //定义一个ADNSDateParseBlock数组,数组长度为[kParserNum + 1],并全部初始化值为0
    static YYNSDateParseBlock blocks[kParserNum + 1] = {0};
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        {
            /*
             2014-01-20  // Google
             */
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter.dateFormat = @"yyyy-MM-dd";
            // 日期的字符串长度为10
            blocks[10] = ^(NSString *string) { return [formatter dateFromString:string]; };
        }
        
        {
            /*
             格式1：2014-01-20 12:24:48
             格式2：2014-01-20T12:24:48   // Google
             格式3：2014-01-20 12:24:48.000
             格式4：2014-01-20T12:24:48.000
             */
            
            /** 长度为19的日期字符串解析，分两种
             */
            NSDateFormatter *formatter1 = [[NSDateFormatter alloc] init];
            formatter1.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter1.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter1.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
            
            NSDateFormatter *formatter2 = [[NSDateFormatter alloc] init];
            formatter2.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter2.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter2.dateFormat = @"yyyy-MM-dd HH:mm:ss";
            
            NSDateFormatter *formatter3 = [[NSDateFormatter alloc] init];
            formatter3.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter3.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter3.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS";
            
            NSDateFormatter *formatter4 = [[NSDateFormatter alloc] init];
            formatter4.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter4.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter4.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
            // 将日期字符串解析的Block保存到19的数组位置
            blocks[19] = ^(NSString *string) {
                if ([string characterAtIndex:10] == 'T') { // 格式2
                    return [formatter1 dateFromString:string];
                } else { // 格式1
                    return [formatter2 dateFromString:string];
                }
            };
            // 将日期字符串解析的Block保存到23的数组位置
            blocks[23] = ^(NSString *string) {
                if ([string characterAtIndex:10] == 'T') { // 格式3
                    return [formatter3 dateFromString:string];
                } else { // 格式4
                    return [formatter4 dateFromString:string];
                }
            };
        }
        
        {
            /*
             格式1：2014-01-20T12:24:48Z        // Github, Apple
             格式2：2014-01-20T12:24:48+0800    // Facebook
             格式3：2014-01-20T12:24:48+12:00   // Google
             格式4：2014-01-20T12:24:48.000Z
             格式5：2014-01-20T12:24:48.000+0800
             格式6：2014-01-20T12:24:48.000+12:00
             */
            NSDateFormatter *formatter = [NSDateFormatter new];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
            
            NSDateFormatter *formatter2 = [NSDateFormatter new];
            formatter2.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter2.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
            // 将日期字符串解析的Block保存到20的数组位置，格式1
            blocks[20] = ^(NSString *string) { return [formatter dateFromString:string]; };
            // 将日期字符串解析的Block保存到24的数组位置，格式2
            blocks[24] = ^(NSString *string) { return [formatter dateFromString:string]?: [formatter2 dateFromString:string]; };
            // 将日期字符串解析的Block保存到25的数组位置，格式3
            blocks[25] = ^(NSString *string) { return [formatter dateFromString:string]; };
            // 将日期字符串解析的Block保存到28的数组位置，格式4
            blocks[28] = ^(NSString *string) { return [formatter2 dateFromString:string]; };
            // 将日期字符串解析的Block保存到29的数组位置，格式5
            blocks[29] = ^(NSString *string) { return [formatter2 dateFromString:string]; };
        }
        
        {
            /*
             格斯1：Fri Sep 04 00:12:21 +0800 2015 // Weibo, Twitter
             格式2：Fri Sep 04 00:12:21.000 +0800 2015
             */
            NSDateFormatter *formatter = [NSDateFormatter new];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.dateFormat = @"EEE MMM dd HH:mm:ss Z yyyy";
            
            NSDateFormatter *formatter2 = [NSDateFormatter new];
            formatter2.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter2.dateFormat = @"EEE MMM dd HH:mm:ss.SSS Z yyyy";
            // 将日期字符串解析的Block保存到30的数组位置，格式1
            blocks[30] = ^(NSString *string) { return [formatter dateFromString:string]; };
            // 将日期字符串解析的Block保存到34的数组位置，格式2
            blocks[34] = ^(NSString *string) { return [formatter2 dateFromString:string]; };
        }
    });
    // 判断传入值合法性
    if (!string) return nil;
    // 如果传入字符串长度越界，不属于转换的范围内，直接返回nil
    if (string.length > kParserNum) return nil;
    // 设置block数组大小
    YYNSDateParseBlock parser = blocks[string.length];
    if (!parser) return nil;
    return parser(string);//block 解析后格式化返回字符串
#undef kParserNum
}


/// Get the 'NSBlock' class.获得NSBlock类
//获得'NSBlock'类，返回值为强转成类的无参无返Block，且其父类为[NSObject class]
static force_inline Class YYNSBlockClass() {
    static Class cls;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void (^block)(void) = ^{};
        cls = ((NSObject *)block).class; // 获得当前Block的Class
        // 遍历Block（__NSGlobalBlock__ - > __NSGlobalBlock - > NSBlock - > NSObject）最终的superClass，NSBlock的父类是NSObject
        while (class_getSuperclass(cls) != [NSObject class]) {
            cls = class_getSuperclass(cls);
        }
    });
    return cls; // current is "NSBlock"
}


/**
 Get the ISO date formatter. 获得ISO日期格式
 ISO：国际标准化组织的国际标准ISO 8601是日期和时间的表示方法
 ISO8601 format example:
 2010-07-09T16:13:30+12:00
 2011-01-11T11:11:11+0000
 2011-01-26T19:06:43Z
 
 length: 20/24/25
 */
static force_inline NSDateFormatter *YYISODateFormatter() {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 初始化formatter
        formatter = [[NSDateFormatter alloc] init];
        // 设置时区
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        // 设置ISO日期格式
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    });
    return formatter;
}

/// Get the value with key paths from dictionary
/// The dic should be NSDictionary, and the keyPath should not be nil.
/**
 json格式见下面方法

 从一个字典里中根据key paths中包含的key获取一个value
 如果value为字典类型则设置dic为当前value
 但是只获取最后一个value
 dic应该为NSDictionary,keyPath不应该是nil
 */

/** 这里的keyPaths可以这么理解，如果传入的是以下JSON数据，那么keypath.count为2 此时max = 2
 1. i = 0 , 0 = i < 2 = max; 2. url = keyPaths[0] = keyPaths[i]
 3. http://example.com/1.png = value = dic[@"url"], 如果value不是NSDictionary类型直接返回
 4. 0 + 1 =  i + 1 < 2 = max
 5. i++,
 --------------------------
 1. i = 1, 1 = i < 2 = max; 2. desc = keyPath[1] = keyPaths[i]
 3. Happy~ = value = dic[@"desc"], 如果value不是NSDictionary类型直接返回
 4. 1 + 1 < i + 1 < 2 = max 返回该值
 */

/**
 格式2 "photos" : [ 格式2
 {
 "url":"http://example.com/1.png\",
 "desc":"Happy~"
 },
 {
 "url":"http://example.com/2.png\",
 "desc":"Yeah!"
 }
 ]
 */
static force_inline id YYValueForKeyPath(__unsafe_unretained NSDictionary *dic, __unsafe_unretained NSArray *keyPaths) {
    id value = nil;
    for (NSUInteger i = 0, max = keyPaths.count; i < max; i++) {
        value = dic[keyPaths[i]]; // 根据key取值，keypath
        if (i + 1 < max) { // 相当于NSArray数组倒数第二个key
            // 判断该值如果是字典，直接赋值，否则返回Nil，格式2内的格式6
            if ([value isKindOfClass:[NSDictionary class]]) {
                dic = value; //
            } else {
                return nil;
            }
        }
    }
    return value;
}
/// Get the value with multi key (or key path) from dictionary（从字典中获取多个键（或KeyPath值相当于字典）的值）
/// The dic should be NSDictionary（dic是一个字典）
/** json
 {
 "name" : "Happy Birthday",  格式1
 "photos" : [
 {
 "url":"http://example.com/1.png",
 "desc":"Happy~"
 },
 {
 "url":"http://example.com/2.png",
 "desc":"Yeah!"
 }
 ],
 "likedUsers" : { 格式1
 "Jony" : {"uid":10001,"name":"Jony"}, 格式3
 "Anna" : {"uid":10002,"name":"Anna"}, 格式3
 "desc":"Happy~", 格式4
 格式2    "photos" : [ 格式6
 {
 "url":"http://example.com/1.png",
 "desc":"Happy~"
 },
 {
 "url":"http://example.com/2.png", 格式5
 "desc":"Yeah!"
 }
 ]
 },
 "likedUserIds" : [10001,10002]
 }
 
 */
/// Get the value with multi key (or key path) from dictionary
/// The dic should be NSDictionary
static force_inline id YYValueForMultiKeys(__unsafe_unretained NSDictionary *dic, __unsafe_unretained NSArray *multiKeys) {
    id value = nil;
    for (NSString *key in multiKeys) { // 遍历multiKeys数组，依次取出key
        if ([key isKindOfClass:[NSString class]]) { // 如果是key字符类型，根据key从dic直接取出数据，格式1内存在格式4
            value = dic[key];
            if (value) break; // 如果根据key取出对应的值，停止继续取值
        } else { // 根据Key的值如果NSSArray,进入LTValueForKeyPath取出指定key的值，例如格式1内存在格式2
            value = YYValueForKeyPath(dic, (NSArray *)key);
            // 如果根据key取出对应的值，停止继续取值
            if (value) break;
        }
    }
    return value;
}




/// A property info in object model.
//_YYModelPropertyMeta属声明属性详细解析
//
//_name:  属性的名称
//_type： 属性对应的基础类型编码
//_nsType： Foundation框架类型编码
//_isCNumber：判断是否C语言结构类型
//_cls：实例变量来源于哪个类
//_genericCls：如下例子，genericCls = LMBook，该值用来判断是否自定义映射，如果是自定义映射则值为自定义映射的当前类

@interface _YYModelPropertyMeta : NSObject {
    @package
    NSString *_name;             ///< property's name 属性名称
    // 对象类型
    YYEncodingType _type;        ///< property's type  属性的基础类型
    // 对象类型
    YYEncodingNSType _nsType;    ///< property's Foundation type  属性的 Foundation Class类型
    BOOL _isCNumber;             ///< is c number type 是否是C语言结构类型
    //  实例变量来源于哪个类（可能是父类） */
    Class _cls;                  ///< property's class, or nil
    Class _genericCls;           ///< container's generic class, or nil if threr's no generic  容器的通用类，如果()没有通用class为nil，自定义类
    SEL _getter;                 ///< getter, or nil if the instances cannot respond，保存属性的getter方法
    SEL _setter;                 ///< setter, or nil if the instances cannot respond 保存属性的setter方法
    BOOL _isKVCCompatible;       ///< YES if it can access with key-value coding 类型是否不支持KVC
    BOOL _isStructAvailableForKeyedArchiver; ///< YES if the struct can encoded with keyed archiver/unarchiver 结构是否支持 archiver（归档）/unarchiver（解档）
    BOOL _hasCustomClassFromDictionary; ///< class/generic class implements +modelCustomClassForDictionary:  字典转模型是否类被实现
    
    /*
     property->key:       _mappedToKey:key     _mappedToKeyPath:nil            _mappedToKeyArray:nil
     property->keyPath:   _mappedToKey:keyPath _mappedToKeyPath:keyPath(array) _mappedToKeyArray:nil
     property->keys:      _mappedToKey:keys[0] _mappedToKeyPath:nil/keyPath    _mappedToKeyArray:keys(array)
     */
    /**
     */
    NSString *_mappedToKey;      ///< the key mapped to  to key
    // 如果有多级映射   如果有多个属性映射到相同的键会用到
    NSArray *_mappedToKeyPath;   ///< the key path mapped to (nil if the name is not key path)
    NSArray *_mappedToKeyArray;  ///< the key(NSString) or keyPath(NSArray) array (nil if not mapped to multiple keys)
    YYClassPropertyInfo *_info;  ///< property's info
    _YYModelPropertyMeta *_next; ///< next meta if there are multiple properties mapped to the same key.  下一个元，如果有多个属性映射到相同的键。
}
@end

@implementation _YYModelPropertyMeta
// 根据YYClassInfo信息初始化YYClassInfo并且设置对应属性信息
+ (instancetype)metaWithClassInfo:(YYClassInfo *)classInfo propertyInfo:(YYClassPropertyInfo *)propertyInfo generic:(Class)generic {
    _YYModelPropertyMeta *meta = [self new];
    meta->_name = propertyInfo.name;
    meta->_type = propertyInfo.type;
    meta->_info = propertyInfo;
    meta->_genericCls = generic;
    
    // 如果属性的类型编码是对象，例如id, NSDate...,如果是对象类型那么一般是Foundation类型，直接根据属性的属性的类信息传入当前属性class信息或者对应Foundation类型
    if ((meta->_type & YYEncodingTypeMask) == YYEncodingTypeObject) { // 属性的 Foundation Class类型
        meta->_nsType = YYClassGetNSType(propertyInfo.cls);
    } else { // 属性是c语言基础类型
        meta->_isCNumber = YYEncodingTypeIsCNumber(meta->_type);
    }
    if ((meta->_type & YYEncodingTypeMask) == YYEncodingTypeStruct) { // 属性是结构体类型
        /*
         It seems that NSKeyedUnarchiver cannot decode NSValue except these structs:
         iOS能够归档的struct类型有限制，能够使用归档的struct类型type encodings为如下:
         32 bit struct类型的 @encode()
         */
        static NSSet *types = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSMutableSet *set = [NSMutableSet new];
            // 32 bit
            [set addObject:@"{CGSize=ff}"];
            [set addObject:@"{CGPoint=ff}"];
            [set addObject:@"{CGRect={CGPoint=ff}{CGSize=ff}}"];
            [set addObject:@"{CGAffineTransform=ffffff}"];
            [set addObject:@"{UIEdgeInsets=ffff}"];
            [set addObject:@"{UIOffset=ff}"];
            
            /**
             iOS能够归档的struct类型有限制，能够使用归档的struct类型type encodings为如下:
             64 bit struct类型的 @encode()
             */
            // 64 bit
            [set addObject:@"{CGSize=dd}"];
            [set addObject:@"{CGPoint=dd}"];
            [set addObject:@"{CGRect={CGPoint=dd}{CGSize=dd}}"];
            [set addObject:@"{CGAffineTransform=dddddd}"];
            [set addObject:@"{UIEdgeInsets=dddd}"];
            [set addObject:@"{UIOffset=dd}"];
            types = set;
        });
        if ([types containsObject:propertyInfo.typeEncoding]) {
            meta->_isStructAvailableForKeyedArchiver = YES;
        }
    }
    meta->_cls = propertyInfo.cls;
    
    if (generic) { // 如果存在自定义映射
        // 从传入的generic class读取自定义映射，设置该代理方法为第一响应
        meta->_hasCustomClassFromDictionary = [generic respondsToSelector:@selector(modelCustomClassForDictionary:)];
    } else if (meta->_cls && meta->_nsType == YYEncodingTypeNSUnknown) { // 属性类名不为空且不是Foundation类型
        meta->_hasCustomClassFromDictionary = [meta->_cls respondsToSelector:@selector(modelCustomClassForDictionary:)];  // 从属性变量类型的Class读取自定义映射，并且设置该代理方法为第一响应
    }
    // 保存Property的getter
    if (propertyInfo.getter) {
        /**
         instancesRespondToSelector：被调用时，动态方法是有机会的首先为selector提供一个IMP，如果该类对应的Property有getter方法实现方法，则返回YES
         */
        if ([classInfo.cls instancesRespondToSelector:propertyInfo.getter]) {
            meta->_getter = propertyInfo.getter; // 从属性列表获取响应属性的getter方法
        }
    }
    // 保存Property的setter
    if (propertyInfo.setter) {
        /**
         instancesRespondToSelector：被调用时，动态方法是有机会的首先为selector提供一个IMP，如果该类对应的Property有setter方法实现方法，则返回YES
         */
        if ([classInfo.cls instancesRespondToSelector:propertyInfo.setter]) {
            meta->_setter = propertyInfo.setter;
        }
    }
    /** 属性变量是否支持KVC,有一个条件
     * getter/setter方法必须实现
     */
    if (meta->_getter && meta->_setter) {
        /*
         KVC invalid type:
         long double
         pointer (such as SEL/CoreFoundation object)
         */
        /** 有两种类型不支持KVC
         * 1.long double 不支持KVC
         * 2. pointer (such as SEL/CoreFoundation object) 不支持KVC
         */
        switch (meta->_type & YYEncodingTypeMask) {
            case YYEncodingTypeBool:
            case YYEncodingTypeInt8:
            case YYEncodingTypeUInt8:
            case YYEncodingTypeInt16:
            case YYEncodingTypeUInt16:
            case YYEncodingTypeInt32:
            case YYEncodingTypeUInt32:
            case YYEncodingTypeInt64:
            case YYEncodingTypeUInt64:
            case YYEncodingTypeFloat:
            case YYEncodingTypeDouble:
            case YYEncodingTypeObject:
            case YYEncodingTypeClass:
            case YYEncodingTypeBlock:
            case YYEncodingTypeStruct:
            case YYEncodingTypeUnion: {
                meta->_isKVCCompatible = YES;
            } break;
            default: break;
        }
    }
    
    return meta;
}
@end


/// A class info in object model.
@interface _YYModelMeta : NSObject {
    @package
    YYClassInfo *_classInfo;
    //    Key:映射key和key path,value:_YYModelPropertyMeta
    /// Key:mapped key and key path, Value:_YYModelPropertyInfo.
    NSDictionary *_mapper;
    /// Array<_YYModelPropertyMeta>, all property meta of this model.
    //    数组<_YYModelPropertyMeta>,关于model的所有property元素
    NSArray *_allPropertyMetas;
    /// Array<_YYModelPropertyMeta>, property meta which is mapped to a key path.
    //    数组<_YYModelPropertyMeta>,property元素映射到的一个key path
    NSArray *_keyPathPropertyMetas;
    //    数组<_YYModelPropertyMeta>,property元素映射到的多个key
    /// Array<_YYModelPropertyMeta>, property meta which is mapped to multi keys.
    NSArray *_multiKeysPropertyMetas;
    /// The number of mapped key (and key path), same to _mapper.count.
    //    关于映射的key(与key path)的数字，等同于_mapper.count
    NSUInteger _keyMappedCount;
    //    Model class 类型
    /// Model class type.
    YYEncodingNSType _nsType;
    
    /**
     @protocol YYModel <NSObject>
     @optional 协议是否实现
     */
    BOOL _hasCustomWillTransformFromDictionary;
    BOOL _hasCustomTransformFromDictionary;
    BOOL _hasCustomTransformToDictionary;
    BOOL _hasCustomClassFromDictionary;
}
@end

@implementation _YYModelMeta

//自定义方法，未在.h声明
- (instancetype)initWithClass:(Class)cls {
    YYClassInfo *classInfo = [YYClassInfo classInfoWithClass:cls];
    if (!classInfo) return nil;
    self = [super init];
    
    // Get black list 黑名单
    // Get black list
    //    获取黑名单
    /**
     在model变换时所有在黑名单里的property都将被忽视
     返回 一个关于property name的数组
     */
    NSSet *blacklist = nil;
    // 由用户传入的黑名单属性，不对其进行Json解析
    if ([cls respondsToSelector:@selector(modelPropertyBlacklist)]) {
        NSArray *properties = [(id<YYModel>)cls modelPropertyBlacklist];
        if (properties) {
            blacklist = [NSSet setWithArray:properties];
        }
    }
    
    // Get white list  白名单
    NSSet *whitelist = nil;
     // 由用户传入的白名单属性，解析
    if ([cls respondsToSelector:@selector(modelPropertyWhitelist)]) {
        NSArray *properties = [(id<YYModel>)cls modelPropertyWhitelist];
        if (properties) {
            whitelist = [NSSet setWithArray:properties];
        }
    }
    
    // Get container property's generic class
    // 存储自定义映射Class字典
    // 存储自定义映射Class字典
    NSDictionary *genericMapper = nil;
    /**
     描述:    如果这个property是一个对象容器，列如NSArray/NSSet/NSDictionary
     实现这个方法并返回一个属性->类mapper,告知哪一个对象将被添加到这个array /set /
     */
    if ([cls respondsToSelector:@selector(modelContainerPropertyGenericClass)]) {
        genericMapper = [(id<YYModel>)cls modelContainerPropertyGenericClass];
        if (genericMapper) { // 如果存在自定义映射Class，也就是说modelContainerPropertyGenericClass方法被实现了
            NSMutableDictionary *tmp = [NSMutableDictionary new];
            /**
             + (NSDictionary *)modelContainerPropertyGenericClass {
             return @{@"photos" : YYPhoto.class,
             @"likedUsers" : YYUser.class,
             @"likedUserIds" : NSNumber.class};
             }
             */
            [genericMapper enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) { // 遍历字典
                // 如果传入的Key是字典或者数组直接返回
                if (![key isKindOfClass:[NSString class]]) return;
                /// 根据key获得对应的Class类型
                Class meta = object_getClass(obj);
                // 合法性检查，meta为空
                if (!meta) return;
                //
                if (class_isMetaClass(meta)) { // 如果传入的格式这样：YYUser.class 或 [YYUser class]；或 Foundation Type
                    tmp[key] = obj;
                } else if ([obj isKindOfClass:[NSString class]]) { // 如果传入的格式这样：@“YYUser”
                    Class cls = NSClassFromString(obj); // 获得一个类的名称;如果当前项目没有加载这个类，返回nil
                    if (cls) { // 有该类存在
                        tmp[key] = cls; // 以json Key为key，value为所指定的类存入字典
                    }
                }
            }];
            // 遍历字典校验完毕后，传给自定义映射字典genericMapper
            genericMapper = tmp;
        }
    }
    
    // Create all property metas. 存储所有的property metas
    NSMutableDictionary *allPropertyMetas = [NSMutableDictionary new];
    YYClassInfo *curClassInfo = classInfo; // 传入的Class
    while (curClassInfo && curClassInfo.superCls != nil) { // recursive(递归) parse super class, but ignore root class (NSObject/NSProxy)（不对 Root Class（(NSObject/NSProxy)） 做解析）
        
        // 1. classInfo - > propertyInfo; 2. classInfo -> propertyInfo -> PropertyMeta
        for (YYClassPropertyInfo *propertyInfo in curClassInfo.propertyInfos.allValues) { // 遍历class所有的属性
            if (!propertyInfo.name) continue; // 合法性检查
            if (blacklist && [blacklist containsObject:propertyInfo.name]) continue;
            if (whitelist && ![whitelist containsObject:propertyInfo.name]) continue;
            // 初始化_YYModelPropertyMeta，classInfo -> propertyInfo -> PropertyMeta
            _YYModelPropertyMeta *meta = [_YYModelPropertyMeta metaWithClassInfo:classInfo
                                                                    propertyInfo:propertyInfo
                                                                         generic:genericMapper[propertyInfo.name]]; // 根据传入的参数，对PropertyMeta相关属性进行设置，返回元组信息
            if (!meta || !meta->_name) continue;
            if (!meta->_getter || !meta->_setter) continue; // 没有实现setter,getter
            if (allPropertyMetas[meta->_name]) continue; // 已经解析过的直接跳过
            allPropertyMetas[meta->_name] = meta; // 把属性的名称作为key存入allPropertyMetas,该字典存放所有的property metas
        }
        // 紧接着遍历父类信息
        curClassInfo = curClassInfo.superClassInfo;
    }
    if (allPropertyMetas.count) _allPropertyMetas = allPropertyMetas.allValues.copy;
    
    // create mapper
    NSMutableDictionary *mapper = [NSMutableDictionary new];
    NSMutableArray *keyPathPropertyMetas = [NSMutableArray new];
    NSMutableArray *multiKeysPropertyMetas = [NSMutableArray new];
    
    if ([cls respondsToSelector:@selector(modelCustomPropertyMapper)]) { // 是否创建映射
        // 返回自定义属性映射字典
        NSDictionary *customMapper = [(id <YYModel>)cls modelCustomPropertyMapper];
        // 遍历自定义属性字典，进行校验
        [customMapper enumerateKeysAndObjectsUsingBlock:^(NSString *propertyName, NSString *mappedToKey, BOOL *stop) {  // propertyName类中的属性名 mappedToKey  json当中的属性名
            // 根据属性名从allPropertyMetas取出对应的PropertyMetas
            _YYModelPropertyMeta *propertyMeta = allPropertyMetas[propertyName];
            if (!propertyMeta) return; // // 如果allPropertyMetas不存在该属性，也就是说想要属性映射并不存在该属性，那么是无法映射的，直接返回。allPropertyMetas相当于每个类的集合，存放所有的属性
            // 如果存在该属性，移除该属性，替换映射的属性名
            [allPropertyMetas removeObjectForKey:propertyName];
            // 确保映射的属性不是字典数组乱七八糟的类型
            if ([mappedToKey isKindOfClass:[NSString class]]) { // 映射属性名 @"page"  : @"p"
                // 映射属性名合法性校验
                /**
                 @"time":@"t";
                 */
                if (mappedToKey.length == 0) return;
                // 属性名映射一个简单的Json Key
                propertyMeta->_mappedToKey = mappedToKey; // 设置新属性名（映射的名称）
                
                // 如果有多级映射   componentsSeparatedByString:将字符串切割成数组
                /**
                 "ext" : {
                 "desc" : "A book written by J.K.Rowling."
                 },
                 格式1：
                 @"desc"  : @"ext.desc",
                 存在点语法映射情况
                 
                 keyPath---(
                 ext,
                 desc
                 )
                 
                 格式2：
                 @{@"messageId":@"i",
                 @"content":@"c",
                 @"time":@"t"};
                 
                 */
                NSArray *keyPath = [mappedToKey componentsSeparatedByString:@"."]; // @"desc"  : @"ext.desc",
                if (keyPath.count > 1) { // 属性名映射一个Json keypath,如果是多级映射，keyPath = @[@"ect",@"desc"];，保存属性映射的json keyPaths
                    propertyMeta->_mappedToKeyPath = keyPath;
                    // 属性添加到使用keypaths映射的数组
                    [keyPathPropertyMetas addObject:propertyMeta];
                }
                /** 字符串格式3 多个属性映射同一个mappedToKey
                 {@"name":@"name", @"title":@"name", @"tip":@"name"}
                 */
                // 将多级映射中Key设置下一个属性
                // 使用Next指针串联mapper保存的mappedToKey当前映射的PropertyMeta对象
                propertyMeta->_next = mapper[mappedToKey] ?: nil; // 第一次不执行
                // 然后 再保存mappedToKey为key 映射 当前新的PropertyMeta对象
                mapper[mappedToKey] = propertyMeta; // 1.以映射属性名为Key将（propertyMeta）属性列表存入字典，如果是格式1多级映射propertyMeta->_mappedToKeyPath存在
                
            } else if ([mappedToKey isKindOfClass:[NSArray class]]) { // 如果映射的格式为  @"bookID": @[@"id", @"ID", @"book_id"]}; 同一个属性名映射到多个json key
                
                NSMutableArray *mappedToKeyArray = [NSMutableArray new];
                // 遍历 mappedToKey 数组
                for (NSString *oneKey in ((NSArray *)mappedToKey)) {
                    // 每一个 数组元素oneKey 必须是字符串
                    if (![oneKey isKindOfClass:[NSString class]]) continue;
                    // 字符串合法性校验
                    if (oneKey.length == 0) continue;
                    // 多个属性如果还有多级映射关系，例如 @"bookID": @[@"id", @"ext.ID", @"book_id"]}
                    NSArray *keyPath = [oneKey componentsSeparatedByString:@"."];
                    if (keyPath.count > 1) { // NSArray
                        // keypath 当做一个数组保存到数组，例如保存@[@"ext",@"ID"]
                        [mappedToKeyArray addObject:keyPath];
                    } else { // NSString
                        // keypath 当做一个字符串保存到数组，例如保存id、book_id
                        [mappedToKeyArray addObject:oneKey];
                    }
                    // 因为是 `一个属性` 映射 `多个json key
                    // 只能保存第一个_mappedToKey(json key)，否则后面的_mappedToKey被覆盖了
                    if (!propertyMeta->_mappedToKey) {   //  _mappedToKeyPath可能为nil;_mappedToKey,_mappedToKeyPath这两个属性可以为后面的方法区别用多级映射(multi)或者一级映射方法
                        propertyMeta->_mappedToKey = oneKey; // 保存数组中第一个oneKey，例如id
                        propertyMeta->_mappedToKeyPath = keyPath.count > 1 ? keyPath : nil; // 保存数组中第一个_mappedToKeyPath,例如ext.ID
                    }
                }
                // 属性 没有映射任何的json key
                if (!propertyMeta->_mappedToKey) return;
                // 保存 当前属性描述的所有json key 映射数组
                propertyMeta->_mappedToKeyArray = mappedToKeyArray;
                // 记录一个 <1属性:n 个 jsonkey>映射关系 的属性
                [multiKeysPropertyMetas addObject:propertyMeta];
                // 多（属性）对一（json key）
                propertyMeta->_next = mapper[mappedToKey] ?: nil;
                mapper[mappedToKey] = propertyMeta;
            }
        }];
    }
    // 注意，如上只对映射字典中给出的属性进行处理
    // 如上处理过的属性都从属性字典中删除
    // allPropertyMetas此时剩下的属性，都是没有配置映射规则的
    // 处理没有映射配置的属性
    // 默认 属性映射json key >>>> 属性的名字
    [allPropertyMetas enumerateKeysAndObjectsUsingBlock:^(NSString *name, _YYModelPropertyMeta *propertyMeta, BOOL *stop) {
        // 简单属性映射
        propertyMeta->_mappedToKey = name;
        // 让映射到相同json key的 不同属性(多属性对一个json key) 使用next指针串联
        propertyMeta->_next = mapper[name] ?: nil;
        // 保存新的映射json key
        mapper[name] = propertyMeta;
    }];
    // 修正映射配置数据
    if (mapper.count) _mapper = mapper;
    if (keyPathPropertyMetas) _keyPathPropertyMetas = keyPathPropertyMetas;
    if (multiKeysPropertyMetas) _multiKeysPropertyMetas = multiKeysPropertyMetas;
    
    _classInfo = classInfo;
    _keyMappedCount = _allPropertyMetas.count;
    _nsType = YYClassGetNSType(cls);
    /**
     @protocol YYModel <NSObject>
     @optional
     */
    /**
     instancesRespondToSelector：被调用时，动态方法是有机会的首先为selector提供一个IMP，如果该类对应的Property有modelCustomWillTransformFromDictionary/modelCustomTransformFromDictionary/modelCustomTransformToDictionary/_hasCustomClassFromDictionary方法实现方法，则返回YES
     **/
    _hasCustomWillTransformFromDictionary = ([cls instancesRespondToSelector:@selector(modelCustomWillTransformFromDictionary:)]);
    _hasCustomTransformFromDictionary = ([cls instancesRespondToSelector:@selector(modelCustomTransformFromDictionary:)]);
    _hasCustomTransformToDictionary = ([cls instancesRespondToSelector:@selector(modelCustomTransformToDictionary:)]);
    _hasCustomClassFromDictionary = ([cls respondsToSelector:@selector(modelCustomClassForDictionary:)]);
    
    return self;
}
/**
 modelCustomWillTransformFromDictionary:
 这个方法行为是相似的与 "- (BOOL)modelCustomTransformFromDictionary:(NSDictionary *)dic"
 但在model转换前被命名的
 描述 如果model实现了这个方法,它将被命名在"+modelWithJson:","+modelWithDictionary:","-modelSetWithJSON:"and"-modelSetWithDictionary:"之前
 如果方法返回为nil,转换过程中将忽视这个model
 @param dic  The json/kv dictionary.
 参数 dic     json/kv 字典
 @return Returns the modified dictionary, or nil to ignore this model.
 返回     返回修改的字典，如果忽视这个model返回Nil
 */
//_hasCustomWillTransformFromDictionary = ([cls instancesRespondToSelector:@selector(modelCustomWillTransformFromDictionary:)]);
/**
 modelCustomTransformFromDictionary:
 如果默认的json-to-model转换并不符合你的model对象,实现这个方法去增加额外的过程。
 你也可以使用这个方法使model的property生效
 描述 如果model实现了这个方法,它将被命名在"+modelWithJSON:","+modelWithDictionary","-modelSetWithJSON:" and "-modelSetWithDictionary:"结束
 @param dic  The json/kv dictionary.
 
 参数 dic json/kv 字典
 
 @return Returns YES if the model is valid, or NO to ignore this model.
 
 返回 如果这个model是有效的,返回YES 或返回NO忽视这个model
 
 */
//_hasCustomTransformFromDictionary = ([cls instancesRespondToSelector:@selector(modelCustomTransformFromDictionary:)]);
/**
 modelCustomTransformToDictionary:
 如果默认的model-to-json转换并不符合你的model class,实现这个方法添加额外的过程。
 你也可以使用这个方法使这个json dictionary有效
 描述 如果这个model实现了这个方法,它将被调用在"-modelToJSONObject"和"-modelToJSONStrign"结束
 如果这个方法返回NO,这个转换过程将忽视这个json dictionary
 */
//_hasCustomTransformToDictionary = ([cls instancesRespondToSelector:@selector(modelCustomTransformToDictionary:)]);
/**
 modelCustomClassForDictionary:
 如果你需要在json->object的改变时创建关于不同类的对象
 使用这个方法基于dictionary data去改变custom class
 描述 如果model实现了这个方法,他将被认为通知是确定的class结果
 在"+modelWithJson","+modelWithDictionary"期间，父对象包含的property是一个对象
 (两个单数的并经由`+modelContainerPropertyGenericClass`包含)
 */
//_hasCustomClassFromDictionary = ([cls respondsToSelector:@selector(modelCustomClassForDictionary:)]);

/// Returns the cached model class meta 缓存优化 Class 与 _YYModelMeta对象
+ (instancetype)metaWithClass:(Class)cls {
    // 空处理
    if (!cls) return nil;
    // 单例字典来缓存优化处理_YYModelMeta对象，类似YYClassInfo对象
    static CFMutableDictionaryRef cache;  // 字典：保存数据
    static dispatch_once_t onceToken;
    // dispatch_semaphore_t 计数器
    static dispatch_semaphore_t lock;
    dispatch_once(&onceToken, ^{
        // // 初始化字典
        cache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        /** dispatch_semaphore_create
         创建新的计数信号量的初始值。
         新创建的信号量，或nil失败。
         创建一个信号量，只允许一个线程通过
         */
        lock = dispatch_semaphore_create(1);
    });
    /**  dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
     如果semaphore计数大于等于1.计数－1，返回，程序继续运行。如果计数为0，则等待。DISPATCH_TIME_FOREVER这里设置的等待时间是一直等待。dispatch_semaphore_signal(semaphore);
     计数＋1.在这两句代码中间的执行代码，每次只会允许一个线程进入，这样就有效的保证了在多线程环境下，只能有一个线程进入。
     **/
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    // // 查询缓存获取_YYModelMeta对象
    _YYModelMeta *meta = CFDictionaryGetValue(cache, (__bridge const void *)(cls));
    // dispatch_semaphore_signal(semaphore);计数＋1.在这两句代码中间的执行代码，
    //每次只会允许一个线程进入，这样就有效的保证了在多线程环境下，只能有一个线程进入。
    dispatch_semaphore_signal(lock);
    if (!meta || meta->_classInfo.needUpdate) {
        // 初始化_YYModelMeta传入cls对象设置相应的属性 = 更新
        meta = [[_YYModelMeta alloc] initWithClass:cls];
        if (meta) { // 更新成功
        
            dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
            // 将更新的结果覆盖原缓存记录
            CFDictionarySetValue(cache, (__bridge const void *)(cls), (__bridge const void *)(meta));
            dispatch_semaphore_signal(lock);
        }
    }
    return meta;
}

@end


/**
 Get number from property.
 @discussion Caller should hold strong reference to the parameters before this function returns.
 @param model Should not be nil.
 @param meta  Should not be nil, meta.isCNumber should be YES, meta.getter should not be nil.
 @return A number object, or nil if failed.
 */
///**
// 通过property获取一个数字
// 描述 调用者(caller 来访者)应对这个参数保持强引用在这个函数返回之前
// 参数 model 不应该是nil
// 参数 meta  不应该是nil,meta.isCNumber 应该是YES,meta.getter不应该是nil
// 返回 一个数字对象，如果获取失败返回nil
// */
/**
 Get number from property.（）
 @discussion Caller should hold strong reference to the parameters before this function returns.
 @param model Should not be nil.
 @param meta  Should not be nil, meta.isCNumber should be YES, meta.getter should not be nil.
 @return A number object, or nil if failed.
 从_YYModelPropertyMeta将c基本数值类型的属性 统一按照 NSNumber 处理。
 discussion:调用方在函数返回之前对参数具有很强的引用。
 @param 模型不应该是nil。
 @param meta不应为零，meta.iscnumber应该为YES，meta.getter不应该是nil。
 “返回一个number对象，如果failed返回nil，
 
 格式:
 ((void (*)(id, SEL, 方法形参类型))(void *) objc_msgSend)(对象, SEL, 方法执行的参数);
 */
static force_inline NSNumber *ModelCreateNumberFromProperty(__unsafe_unretained id model,
                                                            __unsafe_unretained _YYModelPropertyMeta *meta) {
    // 按照不同数据类型取值，并转换成NSNumber
    switch (meta->_type & YYEncodingTypeMask) {
        case YYEncodingTypeBool: {
            return @(((bool (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeInt8: {
            return @(((int8_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeUInt8: {
            return @(((uint8_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeInt16: {
            return @(((int16_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeUInt16: {
            return @(((uint16_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeInt32: {
            return @(((int32_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeUInt32: {
            return @(((uint32_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeInt64: {
            return @(((int64_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeUInt64: {
            return @(((uint64_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeFloat: {
            float num = ((float (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        case YYEncodingTypeDouble: {
            double num = ((double (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        case YYEncodingTypeLongDouble: {
            double num = ((long double (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        default: return nil;
    }
}

/**
 Set number to property.
 @discussion Caller should hold strong reference to the parameters before this function returns.
 @param model Should not be nil.
 @param num   Can be nil.
 @param meta  Should not be nil, meta.isCNumber should be YES, meta.setter should not be nil.
 获取 c基本数值类型的属性值
 discussion: 调用方在函数返回之前对参数具有很强的引用。
 @param:model 被_YYModelMeta解析过的实体类对象
 @param: num  要设置的NSNumber值
 @param:meta:(要设置值的属性的描述对象)   meta不应为nil，meta.iscnumber应该为YES，meta.setter不应该为nil
 格式:
 ((void (*)(id, SEL, 方法形参类型))(void *) objc_msgSend)(对象, SEL, 方法执行的参数);
 */
/**
 设置数字给property
 描述 调用者(caller 来访者)应对这个参数保持强引用在这个函数返回之前
 参数 model 不应该是nil
 参数 num 可以是nil
 参数 meta 不应该是nil，meta.isCNumber应该是YES,meta.setter不应该是Nil
 */
//            objc_msgSend OC消息传递机制中选择子发送的一种方式，代表是当前对象发送且没有结构体返回值
//            选择子简单说就是@selector()，OC会提供一张选择子表供其查询，查询得到就去调用，查询不到就添加而后查询对应的实现函数。通过_class_lookupMethodAndLoadCache3(仅提供给派发器用于方法查找的函数)，其内部会调用lookUpImpOrForward方法查找，查找之后还会有初始化枷锁缓存之类的操作，详情请自行搜索，就不赘述了。
//            这里的意思是，通过objc_msgSend给强转成id类型的model对象发送一个选择子meta，选择子调用的方法所需参数为一个bool类型的值num.boolValue
//            再通俗点就是让对象model去执行方法meta->_setter,方法所需参数是num.bollValue
//            再通俗点：((void (*)(id, SEL, bool))(void *) objc_msgSend) 一位一个无返回值的函数指针，指向id的SEL方法，SEL方法所需参数是bool类型，使用objc_msgSend完成这个id调用SEL方法传递参数bool类型，(void *)objc_msgSend为什么objc_msgSend前加一个(void *)呢？我查了众多资料，众多。最后终于皇天不负有心人有了个结果，是为了避免某些错误，比如model对象的内存被意外侵占了、model对象的isa是一个野指针之类的。要是有大牛能说明白，麻烦再说下。
//            而((id)model, meta->_setter, num.boolValue）则一一对应前面的id,SEL,bool
//            再通俗点。。你找别家吧。。
static force_inline void ModelSetNumberToProperty(__unsafe_unretained id model,
                                                  __unsafe_unretained NSNumber *num,
                                                  __unsafe_unretained _YYModelPropertyMeta *meta) {
    switch (meta->_type & YYEncodingTypeMask) {
        case YYEncodingTypeBool: {
            /** objc_msgSend
             用一个简单的返回值发送消息到一个类的实例。
             方法的返回值。
             
             self
             指向类的实例的一个指针，该实例将接收该消息。
             OP
             处理消息的方法的选择器。
             …
             一个包含参数的变量参数列表。
             返回方法的返回值。
             */
            ((void (*)(id, SEL, bool))(void *) objc_msgSend)((id)model, meta->_setter, num.boolValue);
        } break;
        case YYEncodingTypeInt8: {
            ((void (*)(id, SEL, int8_t))(void *) objc_msgSend)((id)model, meta->_setter, (int8_t)num.charValue);
        } break;
        case YYEncodingTypeUInt8: {
            ((void (*)(id, SEL, uint8_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint8_t)num.unsignedCharValue);
        } break;
        case YYEncodingTypeInt16: {
            ((void (*)(id, SEL, int16_t))(void *) objc_msgSend)((id)model, meta->_setter, (int16_t)num.shortValue);
        } break;
        case YYEncodingTypeUInt16: {
            ((void (*)(id, SEL, uint16_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint16_t)num.unsignedShortValue);
        } break;
        case YYEncodingTypeInt32: {
            ((void (*)(id, SEL, int32_t))(void *) objc_msgSend)((id)model, meta->_setter, (int32_t)num.intValue);
        }
        case YYEncodingTypeUInt32: {
            ((void (*)(id, SEL, uint32_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint32_t)num.unsignedIntValue);
        } break;
        case YYEncodingTypeInt64: {
            if ([num isKindOfClass:[NSDecimalNumber class]]) {
                ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)model, meta->_setter, (int64_t)num.stringValue.longLongValue);
            } else {
                ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint64_t)num.longLongValue);
            }
        } break;
        case YYEncodingTypeUInt64: {
            if ([num isKindOfClass:[NSDecimalNumber class]]) {
                ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)model, meta->_setter, (int64_t)num.stringValue.longLongValue);
            } else {
                ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint64_t)num.unsignedLongLongValue);
            }
        } break;
        case YYEncodingTypeFloat: {
            float f = num.floatValue;
            if (isnan(f) || isinf(f)) f = 0;
            ((void (*)(id, SEL, float))(void *) objc_msgSend)((id)model, meta->_setter, f);
        } break;
        case YYEncodingTypeDouble: {
            double d = num.doubleValue;
            if (isnan(d) || isinf(d)) d = 0;
            ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)model, meta->_setter, d);
        } break;
        case YYEncodingTypeLongDouble: {
            long double d = num.doubleValue;
            if (isnan(d) || isinf(d)) d = 0;
            ((void (*)(id, SEL, long double))(void *) objc_msgSend)((id)model, meta->_setter, (long double)d);
        } // break; commented for code coverage in next line
        default: break;
    }
}

/**
 Set value to model with a property meta.
 
 @discussion Caller should hold strong reference to the parameters before this function returns.
 
 @param model Should not be nil.
 @param value Should not be nil, but can be NSNull.
 @param meta  Should not be nil, and meta->_setter should not be nil.
 
 根据对象属性的描述, 将id类型的对象设置给属性
 
 */
/**
 Set value to model with a property meta.
 设置value给model通过一个property 元素
 
 @discussion Caller should hold strong reference to the parameters before this function returns.
 @param model Should not be nil.
 @param value Should not be nil, but can be NSNull.
 @param meta  Should not be nil, and meta->_setter should not be nil.
 描述 调用者(caller 来访者)应对这个参数保持强引用在这个函数返回之前
 参数 model 不应该是nil
 参数 value 不应该是nil,但可以是NSNull
 参数 meta  不应该是nil,且meta->_setter 不应该是nil
 */
static void ModelSetValueForProperty(__unsafe_unretained id model,
                                     __unsafe_unretained id value,
                                     __unsafe_unretained _YYModelPropertyMeta *meta) {
    
    /** 根据对象属性的描述，来设置id类型的属性值，防止类型转换错误导致崩溃
     
     - 属性`变量类型`
     - 设置给属性的`值类型`
     */
    if (meta->_isCNumber) { // 如果是C语言基本数字类型（注意: NSNumber不是基本类型）
        // id value >>> NSNumber
        NSNumber *num = YYNSNumberCreateFromID(value);
        // 将NSNumber值 设置给实体对象的属性
        ModelSetNumberToProperty(model, num, meta);
        if (num) [num class]; // hold the number 释放num
    } else if (meta->_nsType) { // 如果属性变量是Foundation框架
        if (value == (id)kCFNull) { // 值为空，直接向model的setter发送nil消息
            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)nil);
        } else {
            
            switch (meta->_nsType) { // 区分不同的Foundation Class类型设值
                case YYEncodingTypeNSString: // 如果属性变量是NSString
                case YYEncodingTypeNSMutableString: { // 如果是类型是NSMutableString
                    // 依次判断value类型
                    if ([value isKindOfClass:[NSString class]]) {// 值的类型NSString
                        
                        if (meta->_nsType == YYEncodingTypeNSString) { // 属性类型是NSString
                            // 向model的setter发送value消息
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value); // copy
                        } else { // 属性类型是NSMutaleString
                            
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, ((NSString *)value).mutableCopy); // mutableCopy
                        }
                    } else if ([value isKindOfClass:[NSNumber class]]) { // value类型为NSNumber
                        
                        // 判断类型是NSString/NSMutaleString,向model的setter发送value消息
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                       meta->_setter,
                                                                       (meta->_nsType == YYEncodingTypeNSString) ?
                                                                       ((NSNumber *)value).stringValue :
                                                                       ((NSNumber *)value).stringValue.mutableCopy);
                    } else if ([value isKindOfClass:[NSData class]]) { // value类型为NSData
                        NSMutableString *string = [[NSMutableString alloc] initWithData:value encoding:NSUTF8StringEncoding];
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, string);
                    } else if ([value isKindOfClass:[NSURL class]]) { // value类型为NSURL
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                       meta->_setter,
                                                                       (meta->_nsType == YYEncodingTypeNSString) ?
                                                                       ((NSURL *)value).absoluteString :
                                                                       ((NSURL *)value).absoluteString.mutableCopy);
                    } else if ([value isKindOfClass:[NSAttributedString class]]) {// value类型为NSAttributedString
                        
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                       meta->_setter,
                                                                       (meta->_nsType == YYEncodingTypeNSString) ?
                                                                       ((NSAttributedString *)value).string :
                                                                       ((NSAttributedString *)value).string.mutableCopy);
                    }
                } break;
                    
                case YYEncodingTypeNSValue:
                case YYEncodingTypeNSNumber:
                case YYEncodingTypeNSDecimalNumber: {
                    if (meta->_nsType == YYEncodingTypeNSNumber) { // 属性变量类型是Foundation框架NSNumber
                        // value id -> NSNumber
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, YYNSNumberCreateFromID(value));
                    } else if (meta->_nsType == YYEncodingTypeNSDecimalNumber) { // 属性变量类型是Foundation框架NSDecimalNumber
                        if ([value isKindOfClass:[NSDecimalNumber class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        } else if ([value isKindOfClass:[NSNumber class]]) {
                            NSDecimalNumber *decNum = [NSDecimalNumber decimalNumberWithDecimal:[((NSNumber *)value) decimalValue]];
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, decNum);
                        } else if ([value isKindOfClass:[NSString class]]) {
                            NSDecimalNumber *decNum = [NSDecimalNumber decimalNumberWithString:value];
                            NSDecimal dec = decNum.decimalValue;
                            if (dec._length == 0 && dec._isNegative) {
                                decNum = nil; // NaN
                            }
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, decNum);
                        }
                    } else { // YYEncodingTypeNSValue
                        if ([value isKindOfClass:[NSValue class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        }
                    }
                } break;
                    
                case YYEncodingTypeNSData:
                case YYEncodingTypeNSMutableData: {
                    if ([value isKindOfClass:[NSData class]]) {
                        if (meta->_nsType == YYEncodingTypeNSData) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        } else {
                            NSMutableData *data = ((NSData *)value).mutableCopy;
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, data);
                        }
                    } else if ([value isKindOfClass:[NSString class]]) {
                        NSData *data = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
                        if (meta->_nsType == YYEncodingTypeNSMutableData) {
                            data = ((NSData *)data).mutableCopy;
                        }
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, data);
                    }
                } break;
                    // 属性变量 NSDate
                case YYEncodingTypeNSDate: {
                    if ([value isKindOfClass:[NSDate class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                    } else if ([value isKindOfClass:[NSString class]]) {//value类型是NSString
                        // YYNSDateFromString: NSString转换NSDate
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, YYNSDateFromString(value));
                    }
                } break;
                    
                case YYEncodingTypeNSURL: {
                    if ([value isKindOfClass:[NSURL class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                    } else if ([value isKindOfClass:[NSString class]]) { // value属性类型是NSString,NSString - > NSURL
                        // 字符串去掉多余的空格
                        NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                        NSString *str = [value stringByTrimmingCharactersInSet:set];
                        if (str.length == 0) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, nil);
                        } else {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, [[NSURL alloc] initWithString:str]);
                        }
                    }
                } break;
                    // 属性变量 NSArray、NSMutableArray
                case YYEncodingTypeNSArray:
                case YYEncodingTypeNSMutableArray: {
                    // 看是否配置有自定义映射数组每一个对象的Class映射
                    if (meta->_genericCls) {
                        //  有数组元素Class配置
                        NSArray *valueArr = nil;
                        // 值类型只能是: NSArray、NSSet
                        if ([value isKindOfClass:[NSArray class]]) valueArr = value; // 值是数组
                        else if ([value isKindOfClass:[NSSet class]]) valueArr = ((NSSet *)value).allObjects; // 值是集合
                        // 转换传入的值数组 成为 实体类对象的数组
                        if (valueArr) {
                            // 保存所有转成实体对象的数组
                            NSMutableArray *objectArr = [NSMutableArray new];
                            // 遍历数组每一个对象
                            for (id one in valueArr) {
                                // 支持数组元素类型: 实体类对象、字典对象
                                if ([one isKindOfClass:meta->_genericCls]) {
                                    // 数组元素Class == 配置有映射Class
                                    [objectArr addObject:one];
                                } else if ([one isKindOfClass:[NSDictionary class]]) {
                                    // 数组元素Class == NSDictionary Class，需要转换成实体
                                    
                                    // 获取 属性 配置的 实体类Class
                                    Class cls = meta->_genericCls;
                                    if (meta->_hasCustomClassFromDictionary) { // 有自定义Class映射字典
                                        // 先使用用户设置的修正字典的Class
                                        // 使用 -[NSObject modelCustomClassForDictionary:] 传入当前字典对象，得到的对应Class
                                        cls = [cls modelCustomClassForDictionary:one];
                                        // 如果没有设置，就使用当前属性配置的Class
                                        //使用 -[NSObject mapping_containerPropertiesMappings]返回的属性对应的Class
                                        if (!cls) cls = meta->_genericCls;
                                    }
                                    // 创建一个新的NSObject对象
                                    NSObject *newOne = [cls new];
                                    [newOne modelSetWithDictionary:one];
                                    if (newOne) [objectArr addObject:newOne];
                                }
                            }
                            // 将转换好的数组设置给属性
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, objectArr);
                        }
                    } else { // 没有数组元素Class配置
                        // value是NSArray
                        if ([value isKindOfClass:[NSArray class]]) {
                            if (meta->_nsType == YYEncodingTypeNSArray) {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                            } else {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                               meta->_setter,
                                                                               ((NSArray *)value).mutableCopy);
                            }
                        } else if ([value isKindOfClass:[NSSet class]]) {  // value是NSSet
                            if (meta->_nsType == YYEncodingTypeNSArray) {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, ((NSSet *)value).allObjects);
                            } else {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                               meta->_setter,
                                                                               ((NSSet *)value).allObjects.mutableCopy);
                            }
                        }
                    }
                } break;
                    
                case YYEncodingTypeNSDictionary:
                case YYEncodingTypeNSMutableDictionary: {
                    if ([value isKindOfClass:[NSDictionary class]]) {
                        if (meta->_genericCls) {
                            NSMutableDictionary *dic = [NSMutableDictionary new];
                            [((NSDictionary *)value) enumerateKeysAndObjectsUsingBlock:^(NSString *oneKey, id oneValue, BOOL *stop) {
                                if ([oneValue isKindOfClass:[NSDictionary class]]) {
                                    Class cls = meta->_genericCls;
                                    if (meta->_hasCustomClassFromDictionary) {
                                        cls = [cls modelCustomClassForDictionary:oneValue];
                                        if (!cls) cls = meta->_genericCls; // for xcode code coverage
                                    }
                                    NSObject *newOne = [cls new];
                                    [newOne modelSetWithDictionary:(id)oneValue];
                                    if (newOne) dic[oneKey] = newOne;
                                }
                            }];
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, dic);
                        } else {
                            if (meta->_nsType == YYEncodingTypeNSDictionary) {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                            } else {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                               meta->_setter,
                                                                               ((NSDictionary *)value).mutableCopy);
                            }
                        }
                    }
                } break;
                    // 属性变量 NSArray、NSMutableArray
                case YYEncodingTypeNSSet:
                case YYEncodingTypeNSMutableSet: {
                    NSSet *valueSet = nil;
                    // 属性变量是NSArray类型时
                    // 看是否配置有数组中每一个对象的Class映射
                    
                    // value类型只能是: NSArray、NSSet
                    if ([value isKindOfClass:[NSArray class]]) valueSet = [NSMutableSet setWithArray:value];
                    else if ([value isKindOfClass:[NSSet class]]) valueSet = ((NSSet *)value);
                    // 有数组元素Class配置
                    if (meta->_genericCls) {
                        NSMutableSet *set = [NSMutableSet new];
                        for (id one in valueSet) { // 遍历数组每一个对象
                            if ([one isKindOfClass:meta->_genericCls]) {
                                [set addObject:one];
                            } else if ([one isKindOfClass:[NSDictionary class]]) {
                                Class cls = meta->_genericCls;
                                if (meta->_hasCustomClassFromDictionary) { // 是否实现映射字典
                                    // 数组元素Class == NSDictionary Class，需要转换成实体
                                    // 获取 属性 配置的 实体类Class
                                    cls = [cls modelCustomClassForDictionary:one];
                                    // 支持数组元素类型: 实体类对象、字典对象
                                    if (!cls) cls = meta->_genericCls; // for xcode code coverage
                                }
                                // 创建一个新的NSObject对象
                                NSObject *newOne = [cls new];
                                [newOne modelSetWithDictionary:one];
                                if (newOne) [set addObject:newOne];
                            }
                        }
                        // 将转换好的数组设置给属性
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, set);
                    } else {
                        if (meta->_nsType == YYEncodingTypeNSSet) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, valueSet);
                        } else {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                           meta->_setter,
                                                                           ((NSSet *)valueSet).mutableCopy);
                        }
                    }
                } // break; commented for code coverage in next line
                    
                default: break;
            }
        }
    } else {
        BOOL isNull = (value == (id)kCFNull);
        switch (meta->_type & YYEncodingTypeMask) {
            case YYEncodingTypeObject: {
                if (isNull) {
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)nil);
                } else if ([value isKindOfClass:meta->_cls] || !meta->_cls) {
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)value);
                } else if ([value isKindOfClass:[NSDictionary class]]) {
                    NSObject *one = nil;
                    if (meta->_getter) {
                        one = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
                    }
                    if (one) {
                        [one modelSetWithDictionary:value];
                    } else {
                        Class cls = meta->_cls;
                        if (meta->_hasCustomClassFromDictionary) {
                            cls = [cls modelCustomClassForDictionary:value];
                            if (!cls) cls = meta->_genericCls; // for xcode code coverage
                        }
                        one = [cls new];
                        [one modelSetWithDictionary:value];
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)one);
                    }
                }
            } break;
                
            case YYEncodingTypeClass: {
                if (isNull) {
                    ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)NULL);
                } else {
                    Class cls = nil;
                    if ([value isKindOfClass:[NSString class]]) {
                        cls = NSClassFromString(value);
                        if (cls) {
                            ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)cls);
                        }
                    } else {
                        cls = object_getClass(value);
                        if (cls) {
                            if (class_isMetaClass(cls)) {
                                ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)value);
                            }
                        }
                    }
                }
            } break;
                
            case  YYEncodingTypeSEL: {
                if (isNull) {
                    ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)model, meta->_setter, (SEL)NULL);
                } else if ([value isKindOfClass:[NSString class]]) {
                    SEL sel = NSSelectorFromString(value);
                    if (sel) ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)model, meta->_setter, (SEL)sel);
                }
            } break;
                
            case YYEncodingTypeBlock: {
                // Block类型使用: void (^)(void)
                if (isNull) {
                    ((void (*)(id, SEL, void (^)()))(void *) objc_msgSend)((id)model, meta->_setter, (void (^)())NULL);
                } else if ([value isKindOfClass:YYNSBlockClass()]) {
                    ((void (*)(id, SEL, void (^)()))(void *) objc_msgSend)((id)model, meta->_setter, (void (^)())value);
                }
            } break;
                
                // 注意: c类型需要使用NSValue对象包装
            case YYEncodingTypeStruct:
            case YYEncodingTypeUnion:
            case YYEncodingTypeCArray: {
                if ([value isKindOfClass:[NSValue class]]) {
                    // 传入value的编码
                    const char *valueType = ((NSValue *)value).objCType;
                    // 属性变量类型的编码
                    const char *metaType = meta->_info.typeEncoding.UTF8String;
                    // 比较两个编码的内容是否一致
                    if (valueType && metaType && strcmp(valueType, metaType) == 0) {
                        // 结构体实例使用KVC设置给属性变量
                        [model setValue:value forKey:meta->_name];
                    }
                }
            } break;
                // 指针类型value，使用 void* 万能指针类型
            case YYEncodingTypePointer:
            case YYEncodingTypeCString: {
                if (isNull) {
                    ((void (*)(id, SEL, void *))(void *) objc_msgSend)((id)model, meta->_setter, (void *)NULL);
                } else if ([value isKindOfClass:[NSValue class]]) {
                    NSValue *nsValue = value;
                    // 判断传入值的类型，是否是 void* 指针类型
                    // TODO: 为什么CString要按照void*指针类型了？
                    // 因为 [NSValue valueWithPointer:(nullable const void *)]; 将传入的指针转换成 void* 类型了
                    // 所以再通过NSValue获取到指针的类型时，就是 void* ，而其编码就是 `^v`
                    if (nsValue.objCType && strcmp(nsValue.objCType, "^v") == 0) {
                        ((void (*)(id, SEL, void *))(void *) objc_msgSend)((id)model, meta->_setter, nsValue.pointerValue);
                    }
                }
            } // break; commented for code coverage in next line
                
            default: break;
        }
    }
}

typedef struct {
    // 实体类Class的描述类
    void *modelMeta;  ///< _YYModelMeta
    // 设置给哪个实体类对象
    void *model;      ///< id (self)
    // 要设置的值
    void *dictionary; ///< NSDictionary (json)
} ModelSetContext;



/**
 Apply function for dictionary, to set the key-value pair to model.
 
 @param _key     should not be nil, NSString.
 @param _value   should not be nil.
 @param _context _context.modelMeta and _context.model should not be nil.
 
 对于字典的函数应用，设置key-value配对给model
 参数 _key        不应该是nil,NSString
 参数 _value      不应该是nil
 参数 _context    _context.modelMeta 和 _context.model 不应该是nil
 */
static void ModelSetWithDictionaryFunction(const void *_key, const void *_value, void *_context) {
    //      __unsafe_unretained 指针所指向的地址即使已经被释放没有值了，依旧会指向，如同野指针一样，weak/strong这些则会被置为nil。一般应用于iOS 4与OS X  Snow Leopard(雪豹)中，因为iOS 5以上才能使用weak。
    //
    //      __unsafe_unretained与weak一样，不能持有对象，也就是对象的引用计数不会加1
    //
    //    unsafe_unretained修饰符以外的 strong/ weak/ autorealease修饰符保证其指定的变量初始化为nil。同样的，附有 strong/ weak/ _autorealease修饰符变量的数组也可以保证其初始化为nil。
    //
    //    autorealease(延迟释放,给对象添加延迟释放的标记,出了作用域之后，会被自动添加到"最近创建的"自动释放池中)
    //    为什么使用unsafe_unretained?
    //    作者回答：在 ARC 条件下，默认声明的对象是 strong 类型的，赋值时有可能会产生 retain/release 调用，如果一个变量在其生命周期内不会被释放，则使用 unsafe_unretained 会节省很大的开销。
    //    网友提问： 楼主的偏好是说用unsafe_unretained来代替weak的使用，使用后自行解决野指针的问题吗？
    //    作者回答：关于 unsafe_unretained 这个属性，我只提到需要在性能优化时才需要尝试使用，平时开发自然是不推荐用的。
    
    ModelSetContext *context = _context;
    __unsafe_unretained _YYModelMeta *meta = (__bridge _YYModelMeta *)(context->modelMeta);
    __unsafe_unretained _YYModelPropertyMeta *propertyMeta = [meta->_mapper objectForKey:(__bridge id)(_key)];
    __unsafe_unretained id model = (__bridge id)(context->model);
    while (propertyMeta) {
        if (propertyMeta->_setter) {
            ModelSetValueForProperty(model, (__bridge __unsafe_unretained id)_value, propertyMeta);
        }
        propertyMeta = propertyMeta->_next;
    };
}

/**
 Apply function for model property meta, to set dictionary to model.
 
 @param _propertyMeta should not be nil, _YYModelPropertyMeta.
 @param _context      _context.model and _context.dictionary should not be nil.
 
 应用模型属性元函数，对模型集进行字典。
 @param _propertymeta不应为nil，_yymodelpropertymeta。
 @param _context _context.model和_context.dictionary不应该是nil。
 */

/**
 *  先传入属性描述，再从属性描述获取属性映射的jsonkey，然后从传入的字典获取jsonvalue，然后设置给实体类对象
 *
 *  @param _propertyMeta 属性描述对象
 *  @param context       ModelSetContext实例
 */
static void ModelSetWithPropertyMetaArrayFunction(const void *_propertyMeta, void *_context) {
    // 类型转换
    ModelSetContext *context = _context;
    // 从context获取字典对象
    __unsafe_unretained NSDictionary *dictionary = (__bridge NSDictionary *)(context->dictionary);
    // 属性必须存在setter方法实现
    __unsafe_unretained _YYModelPropertyMeta *propertyMeta = (__bridge _YYModelPropertyMeta *)(_propertyMeta);
    if (!propertyMeta->_setter) return;
    id value = nil;
    
    if (propertyMeta->_mappedToKeyArray) {
        // 属性映射多个_mappedToKey(1.一个字符串key 2.keypath)
        value = YYValueForMultiKeys(dictionary, propertyMeta->_mappedToKeyArray);
    } else if (propertyMeta->_mappedToKeyPath) {
        // 属性映射一个_mappedToKeyPath
        value = YYValueForKeyPath(dictionary, propertyMeta->_mappedToKeyPath);
    } else {
        // 属性映射一个单独的json Ke
        value = [dictionary objectForKey:propertyMeta->_mappedToKey];
    }
    // 将从json字典取出的值设置给实体对象
    if (value) {
        // 取出Context中的实体类对象
        __unsafe_unretained id model = (__bridge id)(context->model);
        // 调用给对象设置id值的c方法
        ModelSetValueForProperty(model, value, propertyMeta);
    }
}

/**
 Returns a valid JSON object (NSArray/NSDictionary/NSString/NSNumber/NSNull), 
 or nil if an error occurs.
 
 @param model Model, can be nil.
 @return JSON object, nil if an error occurs.
 */
static id ModelToJSONObjectRecursive(NSObject *model) {
    if (!model || model == (id)kCFNull) return model;
    if ([model isKindOfClass:[NSString class]]) return model;
    if ([model isKindOfClass:[NSNumber class]]) return model;
    if ([model isKindOfClass:[NSDictionary class]]) {
        if ([NSJSONSerialization isValidJSONObject:model]) return model;
        NSMutableDictionary *newDic = [NSMutableDictionary new];
        [((NSDictionary *)model) enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
            NSString *stringKey = [key isKindOfClass:[NSString class]] ? key : key.description;
            if (!stringKey) return;
            id jsonObj = ModelToJSONObjectRecursive(obj);
            if (!jsonObj) jsonObj = (id)kCFNull;
            newDic[stringKey] = jsonObj;
        }];
        return newDic;
    }
    if ([model isKindOfClass:[NSSet class]]) {
        NSArray *array = ((NSSet *)model).allObjects;
        if ([NSJSONSerialization isValidJSONObject:array]) return array;
        NSMutableArray *newArray = [NSMutableArray new];
        for (id obj in array) {
            if ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]]) {
                [newArray addObject:obj];
            } else {
                id jsonObj = ModelToJSONObjectRecursive(obj);
                if (jsonObj && jsonObj != (id)kCFNull) [newArray addObject:jsonObj];
            }
        }
        return newArray;
    }
    if ([model isKindOfClass:[NSArray class]]) {
        if ([NSJSONSerialization isValidJSONObject:model]) return model;
        NSMutableArray *newArray = [NSMutableArray new];
        for (id obj in (NSArray *)model) {
            if ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]]) {
                [newArray addObject:obj];
            } else {
                id jsonObj = ModelToJSONObjectRecursive(obj);
                if (jsonObj && jsonObj != (id)kCFNull) [newArray addObject:jsonObj];
            }
        }
        return newArray;
    }
    if ([model isKindOfClass:[NSURL class]]) return ((NSURL *)model).absoluteString;
    if ([model isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)model).string;
    if ([model isKindOfClass:[NSDate class]]) return [YYISODateFormatter() stringFromDate:(id)model];
    if ([model isKindOfClass:[NSData class]]) return nil;
    
    
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:[model class]];
    if (!modelMeta || modelMeta->_keyMappedCount == 0) return nil;
    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:64];
    __unsafe_unretained NSMutableDictionary *dic = result; // avoid retain and release in block
    [modelMeta->_mapper enumerateKeysAndObjectsUsingBlock:^(NSString *propertyMappedKey, _YYModelPropertyMeta *propertyMeta, BOOL *stop) {
        if (!propertyMeta->_getter) return;
        
        id value = nil;
        if (propertyMeta->_isCNumber) {
            value = ModelCreateNumberFromProperty(model, propertyMeta);
        } else if (propertyMeta->_nsType) {
            id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
            value = ModelToJSONObjectRecursive(v);
        } else {
            switch (propertyMeta->_type & YYEncodingTypeMask) {
                case YYEncodingTypeObject: {
                    id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = ModelToJSONObjectRecursive(v);
                    if (value == (id)kCFNull) value = nil;
                } break;
                case YYEncodingTypeClass: {
                    Class v = ((Class (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = v ? NSStringFromClass(v) : nil;
                } break;
                case YYEncodingTypeSEL: {
                    SEL v = ((SEL (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = v ? NSStringFromSelector(v) : nil;
                } break;
                default: break;
            }
        }
        if (!value) return;
        
        if (propertyMeta->_mappedToKeyPath) {
            NSMutableDictionary *superDic = dic;
            NSMutableDictionary *subDic = nil;
            for (NSUInteger i = 0, max = propertyMeta->_mappedToKeyPath.count; i < max; i++) {
                NSString *key = propertyMeta->_mappedToKeyPath[i];
                if (i + 1 == max) { // end
                    if (!superDic[key]) superDic[key] = value;
                    break;
                }
                
                subDic = superDic[key];
                if (subDic) {
                    if ([subDic isKindOfClass:[NSDictionary class]]) {
                        subDic = subDic.mutableCopy;
                        superDic[key] = subDic;
                    } else {
                        break;
                    }
                } else {
                    subDic = [NSMutableDictionary new];
                    superDic[key] = subDic;
                }
                superDic = subDic;
                subDic = nil;
            }
        } else {
            if (!dic[propertyMeta->_mappedToKey]) {
                dic[propertyMeta->_mappedToKey] = value;
            }
        }
    }];
    
    if (modelMeta->_hasCustomTransformToDictionary) {
        BOOL suc = [((id<YYModel>)model) modelCustomTransformToDictionary:dic];
        if (!suc) return nil;
    }
    return result;
}

/// Add indent to string (exclude first line)
static NSMutableString *ModelDescriptionAddIndent(NSMutableString *desc, NSUInteger indent) {
    for (NSUInteger i = 0, max = desc.length; i < max; i++) {
        unichar c = [desc characterAtIndex:i];
        if (c == '\n') {
            for (NSUInteger j = 0; j < indent; j++) {
                [desc insertString:@"    " atIndex:i + 1];
            }
            i += indent * 4;
            max += indent * 4;
        }
    }
    return desc;
}

/// Generate a description string
static NSString *ModelDescription(NSObject *model) {
    static const int kDescMaxLength = 100;
    if (!model) return @"<nil>";
    if (model == (id)kCFNull) return @"<null>";
    if (![model isKindOfClass:[NSObject class]]) return [NSString stringWithFormat:@"%@",model];
    
    
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:model.class];
    switch (modelMeta->_nsType) {
        case YYEncodingTypeNSString: case YYEncodingTypeNSMutableString: {
            return [NSString stringWithFormat:@"\"%@\"",model];
        }
        
        case YYEncodingTypeNSValue:
        case YYEncodingTypeNSData: case YYEncodingTypeNSMutableData: {
            NSString *tmp = model.description;
            if (tmp.length > kDescMaxLength) {
                tmp = [tmp substringToIndex:kDescMaxLength];
                tmp = [tmp stringByAppendingString:@"..."];
            }
            return tmp;
        }
            
        case YYEncodingTypeNSNumber:
        case YYEncodingTypeNSDecimalNumber:
        case YYEncodingTypeNSDate:
        case YYEncodingTypeNSURL: {
            return [NSString stringWithFormat:@"%@",model];
        }
            
        case YYEncodingTypeNSSet: case YYEncodingTypeNSMutableSet: {
            model = ((NSSet *)model).allObjects;
        } // no break
            
        case YYEncodingTypeNSArray: case YYEncodingTypeNSMutableArray: {
            NSArray *array = (id)model;
            NSMutableString *desc = [NSMutableString new];
            if (array.count == 0) {
                return [desc stringByAppendingString:@"[]"];
            } else {
                [desc appendFormat:@"[\n"];
                for (NSUInteger i = 0, max = array.count; i < max; i++) {
                    NSObject *obj = array[i];
                    [desc appendString:@"    "];
                    [desc appendString:ModelDescriptionAddIndent(ModelDescription(obj).mutableCopy, 1)];
                    [desc appendString:(i + 1 == max) ? @"\n" : @";\n"];
                }
                [desc appendString:@"]"];
                return desc;
            }
        }
        case YYEncodingTypeNSDictionary: case YYEncodingTypeNSMutableDictionary: {
            NSDictionary *dic = (id)model;
            NSMutableString *desc = [NSMutableString new];
            if (dic.count == 0) {
                return [desc stringByAppendingString:@"{}"];
            } else {
                NSArray *keys = dic.allKeys;
                
                [desc appendFormat:@"{\n"];
                for (NSUInteger i = 0, max = keys.count; i < max; i++) {
                    NSString *key = keys[i];
                    NSObject *value = dic[key];
                    [desc appendString:@"    "];
                    [desc appendFormat:@"%@ = %@",key, ModelDescriptionAddIndent(ModelDescription(value).mutableCopy, 1)];
                    [desc appendString:(i + 1 == max) ? @"\n" : @";\n"];
                }
                [desc appendString:@"}"];
            }
            return desc;
        }
        
        default: {
            NSMutableString *desc = [NSMutableString new];
            [desc appendFormat:@"<%@: %p>", model.class, model];
            if (modelMeta->_allPropertyMetas.count == 0) return desc;
            
            // sort property names
            NSArray *properties = [modelMeta->_allPropertyMetas
                                   sortedArrayUsingComparator:^NSComparisonResult(_YYModelPropertyMeta *p1, _YYModelPropertyMeta *p2) {
                                       return [p1->_name compare:p2->_name];
                                   }];
            
            [desc appendFormat:@" {\n"];
            for (NSUInteger i = 0, max = properties.count; i < max; i++) {
                _YYModelPropertyMeta *property = properties[i];
                NSString *propertyDesc;
                if (property->_isCNumber) {
                    NSNumber *num = ModelCreateNumberFromProperty(model, property);
                    propertyDesc = num.stringValue;
                } else {
                    switch (property->_type & YYEncodingTypeMask) {
                        case YYEncodingTypeObject: {
                            id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            propertyDesc = ModelDescription(v);
                            if (!propertyDesc) propertyDesc = @"<nil>";
                        } break;
                        case YYEncodingTypeClass: {
                            id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            propertyDesc = ((NSObject *)v).description;
                            if (!propertyDesc) propertyDesc = @"<nil>";
                        } break;
                        case YYEncodingTypeSEL: {
                            SEL sel = ((SEL (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            if (sel) propertyDesc = NSStringFromSelector(sel);
                            else propertyDesc = @"<NULL>";
                        } break;
                        case YYEncodingTypeBlock: {
                            id block = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            propertyDesc = block ? ((NSObject *)block).description : @"<nil>";
                        } break;
                        case YYEncodingTypeCArray: case YYEncodingTypeCString: case YYEncodingTypePointer: {
                            void *pointer = ((void* (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            propertyDesc = [NSString stringWithFormat:@"%p",pointer];
                        } break;
                        case YYEncodingTypeStruct: case YYEncodingTypeUnion: {
                            NSValue *value = [model valueForKey:property->_name];
                            propertyDesc = value ? value.description : @"{unknown}";
                        } break;
                        default: propertyDesc = @"<unknown>";
                    }
                }
                
                propertyDesc = ModelDescriptionAddIndent(propertyDesc.mutableCopy, 1);
                [desc appendFormat:@"    %@ = %@",property->_name, propertyDesc];
                [desc appendString:(i + 1 == max) ? @"\n" : @";\n"];
            }
            [desc appendFormat:@"}"];
            return desc;
        }
    }
}


@implementation NSObject (YYModel)

//自定义方法
/**
 _ad_dictionaryWithJSON 类方法，自定义的实现方法并没有相应的方法声明
 接收到了Json文件后先判断Json文件是否为空，判断有两种方式
 if (!json || json == (id)kCFNull)  kCFNull: NSNull的单例，也就是空的意思
 那为什么不用Null、Nil或nil呢？以下为nil，Nil，Null，NSNull的区别
 Nil：对类进行赋空值
 nil：对对象进行赋空值
 Null：对C指针进行赋空操作，如字符串数组的首地址 char *name = NULL
 NSNull：对组合值，如NSArray，Json而言，其内部有值，但值为空
 所以判断条件json不存在或json存在，但是其内部值为空，就直接返回nil
 若son存在且其内部有值，则创建一个空字典(dic)与空NSData(jsonData)值
 而后再判断，若son是NSDictionary类，就直接赋值给字典
 若是NSString类，就将其强制转化为NSString，而后用UTF-8编码处理赋值给jsonData
 若是NSData，就直接赋值给jsonData
 而后判断，而jsonData存在就代表son值转化为二进制NSData，用官方提供的JSON解析就可获取到所需的值赋值为dic，若发现解析后取到得值不是NSDictionary，就代表值不能为dict，因为不是同一类型值，就让dict为nil
 最后返回dict，在这个方法里相当于若JSON文件为NSDictionary类型或可解析成dict的NSData、NSString类型就赋值给dict返回，若不能则返回的dict为nil
 */
+ (NSDictionary *)_yy_dictionaryWithJSON:(id)json {
    // kCFNull: NSNull的单例
    if (!json || json == (id)kCFNull) return nil;
    NSDictionary *dic = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSDictionary class]]) {
        dic = json;
    } else if ([json isKindOfClass:[NSString class]]) {
        jsonData = [(NSString *)json dataUsingEncoding : NSUTF8StringEncoding];
    } else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    if (jsonData) {
        dic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![dic isKindOfClass:[NSDictionary class]]) dic = nil;
    }
    return dic;
}

/**
 Creates and returns a new instance of the receiver from a json.
 This method is thread-safe.
 
 @param json  A json object in `NSDictionary`, `NSString` or `NSData`.
 
 @return A new instance created from the json, or nil if an error occurs.
 */
// 创建并返回一个新的列子，通过收取的一个Json文件
//这个方法是安全的
//参数：json   Json包含的类型可以是NSDictionary、NSString、NSData
//返回:通过json创建的新的对象，如果解析错误就返回为空
+ (instancetype)modelWithJSON:(id)json {
    //将json转换成字典
    NSDictionary *dic = [self _yy_dictionaryWithJSON:json];
    //通过字典转换成所需的实例
    return [self modelWithDictionary:dic];
}

/**
 创建并返回一个新的列子通过参数的key-value字典
 这个方法是安全的
 参数:dictionary 一个key-value字典映射到列子的属性
 字典中任何一对无效的key-value都将被忽视
 返回一个新的列子通过字典创建的，如果解析失败返回为nil
 描述:字典中的key将映射到接收者的property name
 而值将设置给这个Property，如果这个值类型与property不匹配
 这个方法将试图转变这个值基于这些结果：
 结果详情看.h文件
 */

+ (instancetype)modelWithDictionary:(NSDictionary *)dictionary {
    if (!dictionary || dictionary == (id)kCFNull) return nil;
    if (![dictionary isKindOfClass:[NSDictionary class]]) return nil;
    
    Class cls = [self class];
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:cls];
    if (modelMeta->_hasCustomClassFromDictionary) {
        cls = [cls modelCustomClassForDictionary:dictionary] ?: cls;
    }
    
    NSObject *one = [cls new];
    if ([one modelSetWithDictionary:dictionary]) return one;
    return nil;
}
/**
 通过一个json对象设置调用者的property
 json中任何无效的数据都将被忽视
 参数：json 一个关于NSDictionary,NSString,NSData的json对象将映射到调用者的property
 返回：是否成功
 
 */
- (BOOL)modelSetWithJSON:(id)json {
    NSDictionary *dic = [NSObject _yy_dictionaryWithJSON:json];
    return [self modelSetWithDictionary:dic];
}

/**
 通过一个key-value字典设置调用者的属性
 参数：dic  一个Key-Value字典映射到调用者property,字典中任何一对无效的Key-Value都将被忽视
 描述  dictionary中的Key将被映射到调用者的property name 而这个value将设置给property.
 如果value类型与property类型不匹配，这个方法将试图转换这个value基于以下这些值：
 返回  转换是否成功
 */
- (BOOL)modelSetWithDictionary:(NSDictionary *)dic {
    if (!dic || dic == (id)kCFNull) return NO;
    if (![dic isKindOfClass:[NSDictionary class]]) return NO;
    
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:object_getClass(self)];
    if (modelMeta->_keyMappedCount == 0) return NO;
    
    if (modelMeta->_hasCustomWillTransformFromDictionary) {
        dic = [((id<YYModel>)self) modelCustomWillTransformFromDictionary:dic];
        if (![dic isKindOfClass:[NSDictionary class]]) return NO;
    }
    
    ModelSetContext context = {0};
    context.modelMeta = (__bridge void *)(modelMeta);
    context.model = (__bridge void *)(self);
    context.dictionary = (__bridge void *)(dic);
    
    if (modelMeta->_keyMappedCount >= CFDictionaryGetCount((CFDictionaryRef)dic)) {
        //        CFDictionaryApplyFunction 对所有键值执行同一个方法
        //        @function CFDictionaryApplyFunction调用一次函数字典中的每个值。
        //        @param 字典。如果这个参数不是一个有效的CFDictionary,行为是未定义的。
        //        @param 调用字典中每一个值执行一次这个方法。如果这个参数不是一个指针指向一个函数的正确的原型,行为是未定义的。
        //        @param 一个用户自定义的上下文指针大小的值，通过第三个参数作用于这个函数，另有没使用此函数的。如果上下文不是预期的应用功能，则这个行为未定义。
        //        第三个参数的意思，感觉像是让字典所有的键值去执行完方法后，保存在这个上下文指针(如自定义结构体)的指针(指向一个地址，所以自定义的结构体要用&取地址符)所指向的地址，也就是自定义的结构体中。如何保存那？就是这个上下文也会传到参数2中。
        //        也就是dic里面的键值对全部执行完参数2的方法后保存在参数3中,其中参数3也会传到参数2的函数中。

        CFDictionaryApplyFunction((CFDictionaryRef)dic, ModelSetWithDictionaryFunction, &context);
        if (modelMeta->_keyPathPropertyMetas) {
            CFArrayApplyFunction((CFArrayRef)modelMeta->_keyPathPropertyMetas,
                                 CFRangeMake(0, CFArrayGetCount((CFArrayRef)modelMeta->_keyPathPropertyMetas)),
                                 ModelSetWithPropertyMetaArrayFunction,
                                 &context);
        }
        if (modelMeta->_multiKeysPropertyMetas) {
            CFArrayApplyFunction((CFArrayRef)modelMeta->_multiKeysPropertyMetas,
                                 CFRangeMake(0, CFArrayGetCount((CFArrayRef)modelMeta->_multiKeysPropertyMetas)),
                                 ModelSetWithPropertyMetaArrayFunction,
                                 &context);
        }
    } else {
        CFArrayApplyFunction((CFArrayRef)modelMeta->_allPropertyMetas,
                             CFRangeMake(0, modelMeta->_keyMappedCount),
                             ModelSetWithPropertyMetaArrayFunction,
                             &context);
    }
    
    if (modelMeta->_hasCustomTransformFromDictionary) {
        return [((id<YYModel>)self) modelCustomTransformFromDictionary:dic];
    }
    return YES;
}
/**
 产生一个json对象通过调用者的property
 返回一个NSDictionary或NSArray的json对象，如果解析失败返回一个Nil
 了解更多消息观看[NSJSONSerialization isValidJSONObject]
 描述：任何无效的property都将被忽视
 如果调用者是NSArray,NSDictionary或NSSet,他将转换里面的对象为json对象
 */
- (id)modelToJSONObject {
    /*
     Apple said:
     The top level object is an NSArray or NSDictionary.
     All objects are instances of NSString, NSNumber, NSArray, NSDictionary, or NSNull.
     All dictionary keys are instances of NSString.
     Numbers are not NaN or infinity.
  
    /**
     苹果说:
     顶端等级的对象是NSArray 或 NSDictionary
     所有对象是关于NSString,NSNumber,NSArray,NSDictionary或NSNull的列子
     NSString的所有的字典key是列子
     Nunmber并不是NaN或无穷大的
     */
    
    id jsonObject = ModelToJSONObjectRecursive(self);
    if ([jsonObject isKindOfClass:[NSArray class]]) return jsonObject;
    if ([jsonObject isKindOfClass:[NSDictionary class]]) return jsonObject;
    return nil;
}
/**
 创建一个json string‘s data(json字符串二进制数据)通过调用者的property
 返回一个json string's data,如果解析失败返回为空
 描述：任何无效的property都将被忽视
 如果调用者是一个NSArray,NSDictionary或NSSet,它也将转换内部对象为一个Json字符串
 */
- (NSData *)modelToJSONData {
    id jsonObject = [self modelToJSONObject];
    if (!jsonObject) return nil;
    return [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:NULL];
}
/**
 创建一个json string通过调用者的property
 返回一个json string,如果错误产生返回一个nil
 描述 任何无效的property都将被忽视
 如果调用者是NSArray,NSDictionary或NSSet,它也将转换内部对象为一个json string
 */
- (NSString *)modelToJSONString {
    NSData *jsonData = [self modelToJSONData];
    if (jsonData.length == 0) return nil;
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}
/**
 copy一个对象通过调用者的properties
 返回一个copy的对象，如果解析失败则返回为nil
 */
- (id)modelCopy{
    if (self == (id)kCFNull) return self;
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self copy];
    
    NSObject *one = [self.class new];
    for (_YYModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_getter || !propertyMeta->_setter) continue;
        
        if (propertyMeta->_isCNumber) {
            switch (propertyMeta->_type & YYEncodingTypeMask) {
                case YYEncodingTypeBool: {
                    bool num = ((bool (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, bool))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeInt8:
                case YYEncodingTypeUInt8: {
                    uint8_t num = ((bool (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint8_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeInt16:
                case YYEncodingTypeUInt16: {
                    uint16_t num = ((uint16_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint16_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeInt32:
                case YYEncodingTypeUInt32: {
                    uint32_t num = ((uint32_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint32_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeInt64:
                case YYEncodingTypeUInt64: {
                    uint64_t num = ((uint64_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeFloat: {
                    float num = ((float (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, float))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeDouble: {
                    double num = ((double (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeLongDouble: {
                    long double num = ((long double (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, long double))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } // break; commented for code coverage in next line
                default: break;
            }
        } else {
            switch (propertyMeta->_type & YYEncodingTypeMask) {
                case YYEncodingTypeObject:
                case YYEncodingTypeClass:
                case YYEncodingTypeBlock: {
                    id value = ((id (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)one, propertyMeta->_setter, value);
                } break;
                case YYEncodingTypeSEL:
                case YYEncodingTypePointer:
                case YYEncodingTypeCString: {
                    size_t value = ((size_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, size_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, value);
                } break;
                case YYEncodingTypeStruct:
                case YYEncodingTypeUnion: {
                    @try {
                        NSValue *value = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
                        if (value) {
                            [one setValue:value forKey:propertyMeta->_name];
                        }
                    } @catch (NSException *exception) {}
                } // break; commented for code coverage in next line
                default: break;
            }
        }
    }
    return one;
}
/**
 Encode the receiver's properties to a coder.
 
 @param aCoder  An archiver object.
 将调用者property编码为一个Coder
 参数 aCoder 一个对象档案
 */
- (void)modelEncodeWithCoder:(NSCoder *)aCoder {
    if (!aCoder) return;
    if (self == (id)kCFNull) {
        [((id<NSCoding>)self)encodeWithCoder:aCoder];
        return;
    }
    
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) {
        [((id<NSCoding>)self)encodeWithCoder:aCoder];
        return;
    }
    
    for (_YYModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_getter) return;
        
        if (propertyMeta->_isCNumber) {
            NSNumber *value = ModelCreateNumberFromProperty(self, propertyMeta);
            if (value != nil) [aCoder encodeObject:value forKey:propertyMeta->_name];
        } else {
            switch (propertyMeta->_type & YYEncodingTypeMask) {
                case YYEncodingTypeObject: {
                    id value = ((id (*)(id, SEL))(void *)objc_msgSend)((id)self, propertyMeta->_getter);
                    if (value && (propertyMeta->_nsType || [value respondsToSelector:@selector(encodeWithCoder:)])) {
                        if ([value isKindOfClass:[NSValue class]]) {
                            if ([value isKindOfClass:[NSNumber class]]) {
                                [aCoder encodeObject:value forKey:propertyMeta->_name];
                            }
                        } else {
                            [aCoder encodeObject:value forKey:propertyMeta->_name];
                        }
                    }
                } break;
                case YYEncodingTypeSEL: {
                    SEL value = ((SEL (*)(id, SEL))(void *)objc_msgSend)((id)self, propertyMeta->_getter);
                    if (value) {
                        NSString *str = NSStringFromSelector(value);
                        [aCoder encodeObject:str forKey:propertyMeta->_name];
                    }
                } break;
                case YYEncodingTypeStruct:
                case YYEncodingTypeUnion: {
                    if (propertyMeta->_isKVCCompatible && propertyMeta->_isStructAvailableForKeyedArchiver) {
                        @try {
                            NSValue *value = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
                            [aCoder encodeObject:value forKey:propertyMeta->_name];
                        } @catch (NSException *exception) {}
                    }
                } break;
                    
                default:
                    break;
            }
        }
    }
}
/**
 Decode the receiver's properties from a decoder.
 
 @param aDecoder  An archiver object.
 
 @return self
 通过一个decoder解码成对象的property
 参数 aDecoder 一个对象档案
 返回 调用者自己
 */
- (id)modelInitWithCoder:(NSCoder *)aDecoder {
    if (!aDecoder) return self;
    if (self == (id)kCFNull) return self;    
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return self;
    
    for (_YYModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_setter) continue;
        
        if (propertyMeta->_isCNumber) {
            NSNumber *value = [aDecoder decodeObjectForKey:propertyMeta->_name];
            if ([value isKindOfClass:[NSNumber class]]) {
                ModelSetNumberToProperty(self, value, propertyMeta);
                [value class];
            }
        } else {
            YYEncodingType type = propertyMeta->_type & YYEncodingTypeMask;
            switch (type) {
                case YYEncodingTypeObject: {
                    id value = [aDecoder decodeObjectForKey:propertyMeta->_name];
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)self, propertyMeta->_setter, value);
                } break;
                case YYEncodingTypeSEL: {
                    NSString *str = [aDecoder decodeObjectForKey:propertyMeta->_name];
                    if ([str isKindOfClass:[NSString class]]) {
                        SEL sel = NSSelectorFromString(str);
                        ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_setter, sel);
                    }
                } break;
                case YYEncodingTypeStruct:
                case YYEncodingTypeUnion: {
                    if (propertyMeta->_isKVCCompatible) {
                        @try {
                            NSValue *value = [aDecoder decodeObjectForKey:propertyMeta->_name];
                            if (value) [self setValue:value forKey:propertyMeta->_name];
                        } @catch (NSException *exception) {}
                    }
                } break;
                    
                default:
                    break;
            }
        }
    }
    return self;
}
/**
 Get a hash code with the receiver's properties.
 
 @return Hash code.
 通过调用者Property获取到一个哈希Code
 返回 hashCode
 */
- (NSUInteger)modelHash {
    if (self == (id)kCFNull) return [self hash];
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self hash];
    
    NSUInteger value = 0;
    NSUInteger count = 0;
    for (_YYModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_isKVCCompatible) continue;
        value ^= [[self valueForKey:NSStringFromSelector(propertyMeta->_getter)] hash];
        count++;
    }
    if (count == 0) value = (long)((__bridge void *)self);
    return value;
}

/**
 Compares the receiver with another object for equality, based on properties.
 
 @param model  Another object.
 
 @return `YES` if the reciever is equal to the object, otherwise `NO`.
 比较这个调用者和另一个对象是否相同，基于property
 参数 model 另一个对象
 返回 如果两个对象相同则返回YES 否则为NO
 */
- (BOOL)modelIsEqual:(id)model {
    if (self == model) return YES;
    if (![model isMemberOfClass:self.class]) return NO;
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self isEqual:model];
    if ([self hash] != [model hash]) return NO;
    
    for (_YYModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_isKVCCompatible) continue;
        id this = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
        id that = [model valueForKey:NSStringFromSelector(propertyMeta->_getter)];
        if (this == that) continue;
        if (this == nil || that == nil) return NO;
        if (![this isEqual:that]) return NO;
    }
    return YES;
}
/**
 Description method for debugging purposes based on properties.
 
 @return A string that describes the contents of the receiver.
 描述方法为基于属性的Debug目的(Debug模式中基于属性的描述方法)
 返回一个字符串描述调用者的内容
 */
- (NSString *)modelDescription {
    return ModelDescription(self);
}

@end



@implementation NSArray (YYModel)
/**
 通过一个json-array创建并返回一个数组
 这个方法是安全的
 
 参数:cls array中的对象类
 参数:json 一个json array 关于"NSArray","NSString"或"NSData"
 列子:[{"name","Mary"},{name:"Joe"}]
 返回一个数组,如果解析错误则返回nil
 */
+ (NSArray *)modelArrayWithClass:(Class)cls json:(id)json {
    if (!json) return nil;
    NSArray *arr = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSArray class]]) {
        arr = json;
    } else if ([json isKindOfClass:[NSString class]]) {
        jsonData = [(NSString *)json dataUsingEncoding : NSUTF8StringEncoding];
    } else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    if (jsonData) {
        arr = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![arr isKindOfClass:[NSArray class]]) arr = nil;
    }
    return [self modelArrayWithClass:cls array:arr];
}

+ (NSArray *)modelArrayWithClass:(Class)cls array:(NSArray *)arr {
    if (!cls || !arr) return nil;
    NSMutableArray *result = [NSMutableArray new];
    for (NSDictionary *dic in arr) {
        if (![dic isKindOfClass:[NSDictionary class]]) continue;
        NSObject *obj = [cls modelWithDictionary:dic];
        if (obj) [result addObject:obj];
    }
    return result;
}

@end


@implementation NSDictionary (YYModel)
/**
 @return A dictionary, or nil if an error occurs.
 通过一个json文件创建并返回一个字典
 这个方法是安全的
 参数cls  字典中value的对象class
 参数json 一个json的字典是"NSDictionary","NSStirng"或"NSData"的
 列子: {"user1":{"name","Mary"}, "user2": {name:"Joe"}}
 */
+ (NSDictionary *)modelDictionaryWithClass:(Class)cls json:(id)json {
    if (!json) return nil;
    NSDictionary *dic = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSDictionary class]]) {
        dic = json;
    } else if ([json isKindOfClass:[NSString class]]) {
        jsonData = [(NSString *)json dataUsingEncoding : NSUTF8StringEncoding];
    } else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    if (jsonData) {
        dic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![dic isKindOfClass:[NSDictionary class]]) dic = nil;
    }
    return [self modelDictionaryWithClass:cls dictionary:dic];
}
//自定义方法，未在.h声明

+ (NSDictionary *)modelDictionaryWithClass:(Class)cls dictionary:(NSDictionary *)dic {
    if (!cls || !dic) return nil;
    NSMutableDictionary *result = [NSMutableDictionary new];
    for (NSString *key in dic.allKeys) {
        if (![key isKindOfClass:[NSString class]]) continue;
        NSObject *obj = [cls modelWithDictionary:dic[key]];
        if (obj) result[key] = obj;
    }
    return result;
}

@end
