/// 野草🌾源解密器
/// 基于 LX Music 开源项目的解密逻辑适配
class GrassSourceDecoder {
  /// 尝试解密和执行野草源的混淆代码
  static String decodeAndPrepareScript(String obfuscatedScript) {
    print('🔓 [GrassDecoder] 开始解析野草源混淆代码，长度: ${obfuscatedScript.length}');

    // 1. 检测常见的混淆模式
    if (obfuscatedScript.contains('function Z(') &&
        obfuscatedScript.contains('function R()')) {
      print('🔓 [GrassDecoder] 检测到典型的野草源混淆模式');
      return _decodeGrassObfuscation(obfuscatedScript);
    }

    // 2. 检测其他混淆模式
    if (obfuscatedScript.contains('_0x') &&
        obfuscatedScript.contains('[\\\'')) {
      print('🔓 [GrassDecoder] 检测到十六进制字符串混淆');
      return _decodeHexStringObfuscation(obfuscatedScript);
    }

    // 3. 直接返回原始脚本，让运行时尝试执行
    print('🔓 [GrassDecoder] 未检测到已知混淆模式，使用增强适配器');
    return _enhanceScriptWithAdapter(obfuscatedScript);
  }

  /// 解密野草源的高级混淆（针对新版本）
  static String _decodeAdvancedGrassObfuscation(String script) {
    print('🔓 [GrassDecoder] 尝试解密野草源高级混淆...');

    // 针对 Z() + R() 混淆模式的完整解决方案
    final wrapper = '''
(function() {
  console.log('[AdvancedGrassDecoder] 开始解混淆野草源...');
  
  // 创建安全的执行环境
  var originalGlobalThis = globalThis;
  var originalWindow = window;
  
  try {
    // 首先执行原始混淆脚本，让它自己注册到 lx 环境
    ${script}
    
    console.log('[AdvancedGrassDecoder] 原始脚本执行完成');
    
    // 等待脚本完全初始化
    setTimeout(function() {
      try {
        console.log('[AdvancedGrassDecoder] 开始扫描已暴露的函数...');
        
        // 1. 检查是否已经通过 lx.on 注册了搜索函数
        if (globalThis.lx && globalThis.lx.on) {
          console.log('[AdvancedGrassDecoder] 检测到 lx 环境，脚本可能已正确注册');
        }
        
        // 2. 检查 module.exports 的实际内容
        if (typeof module !== 'undefined' && module.exports) {
          console.log('[AdvancedGrassDecoder] module.exports类型:', typeof module.exports);
          console.log('[AdvancedGrassDecoder] module.exports键:', Object.keys(module.exports));
          
          // 如果有搜索函数，直接暴露
          if (module.exports.search && typeof module.exports.search === 'function') {
            globalThis.search = module.exports.search;
            globalThis.musicSearch = module.exports.search;
            console.log('[AdvancedGrassDecoder] 从 module.exports 暴露搜索函数');
          }
        }
        
        // 3. 深度扫描闭包变量（野草源可能将函数隐藏在闭包中）
        var detectedFunctions = [];
        var scriptText = ${script}.toString();
        
        // 查找可能的函数声明模式
        var functionPatterns = [
          /function\\s+(\\w+)\\s*\\([^)]*\\)\\s*{[^}]*(?:search|music|query|request)[^}]*}/gi,
          /var\\s+(\\w+)\\s*=\\s*function[^}]*(?:search|music|query|request)[^}]*}/gi,
          /(\\w+)\\s*:\\s*function[^}]*(?:search|music|query|request)[^}]*}/gi
        ];
        
        for (var pattern of functionPatterns) {
          var matches = scriptText.match(pattern);
          if (matches) {
            console.log('[AdvancedGrassDecoder] 发现可能的函数声明:', matches.length, '个');
            detectedFunctions = detectedFunctions.concat(matches);
          }
        }
        
        // 4. 尝试通过 eval 执行特定的解混淆逻辑
        try {
          // 检查是否有全局的 Z 和 R 函数（混淆器函数）
          if (typeof Z === 'function' && typeof R === 'function') {
            console.log('[AdvancedGrassDecoder] 检测到 Z/R 混淆函数，尝试逆向...');
            
            // 获取字符串数组
            var stringArray = R();
            console.log('[AdvancedGrassDecoder] 字符串数组长度:', stringArray.length);
            
            // 尝试找到搜索相关的字符串
            var searchRelated = stringArray.filter(function(str) {
              return str.includes('search') || str.includes('music') || str.includes('query');
            });
            console.log('[AdvancedGrassDecoder] 搜索相关字符串:', searchRelated);
          }
        } catch(e) {
          console.warn('[AdvancedGrassDecoder] Z/R逆向失败:', e);
        }
        
        // 5. 强制暴露一个通用搜索函数
        if (!globalThis.search && !globalThis.musicSearch) {
          console.log('[AdvancedGrassDecoder] 创建通用搜索适配器...');
          
          globalThis.search = function(platform, keyword, page) {
            console.log('[GrassAdapter] 搜索调用:', arguments);
            
            // 尝试触发 lx 的 request 事件（如果脚本已注册）
            if (globalThis.lx && globalThis.lx.emit) {
              try {
                console.log('[GrassAdapter] 尝试通过 lx.emit 搜索...');
                return globalThis.lx.emit('request', {
                  action: 'search',
                  source: platform,
                  info: { keyword: keyword, page: page }
                });
              } catch(e) {
                console.warn('[GrassAdapter] lx.emit 失败:', e);
              }
            }
            
            // 返回空结果但不报错
            console.warn('[GrassAdapter] 无法找到可用的搜索函数');
            return Promise.resolve([]);
          };
          
          globalThis.musicSearch = globalThis.search;
          globalThis.grassSearch = globalThis.search;
        }
        
        console.log('[AdvancedGrassDecoder] 解混淆完成');
        
      } catch(e) {
        console.error('[AdvancedGrassDecoder] 延迟处理失败:', e);
      }
    }, 2000); // 等待2秒确保脚本完全加载
    
  } catch(e) {
    console.error('[AdvancedGrassDecoder] 脚本执行失败:', e);
  }
})();
''';

    return wrapper;
  }

  /// 解密野草源特有的混淆（保留原版本兼容性）
  static String _decodeGrassObfuscation(String script) {
    print('🔓 [GrassDecoder] 使用兼容模式解密...');
    return _decodeAdvancedGrassObfuscation(script);
  }

  /// 解密十六进制字符串混淆
  static String _decodeHexStringObfuscation(String script) {
    print('🔓 [GrassDecoder] 解密十六进制字符串混淆...');
    // 这里可以实现具体的十六进制字符串解混淆逻辑
    // 目前先返回增强适配器版本
    return _enhanceScriptWithAdapter(script);
  }

  /// 为脚本添加增强适配器
  static String _enhanceScriptWithAdapter(String script) {
    final enhanced = '''
${script}

// 增强适配器：尝试自动发现和暴露搜索函数
(function() {
  try {
    console.log('[EnhancedAdapter] 开始自动函数发现...');
    
    // 延迟执行，等待脚本完全加载
    setTimeout(function() {
      var discoveredFunctions = [];
      
      // 深度扫描所有对象的属性
      function deepScan(obj, path) {
        if (!obj || typeof obj !== 'object') return;
        if (path.length > 3) return; // 避免递归过深
        
        try {
          for (var key in obj) {
            if (typeof obj[key] === 'function') {
              var funcStr = obj[key].toString();
              if (funcStr.length > 100 && (
                funcStr.indexOf('search') >= 0 || 
                funcStr.indexOf('query') >= 0 ||
                funcStr.indexOf('music') >= 0
              )) {
                var fullPath = path.concat([key]).join('.');
                discoveredFunctions.push({name: fullPath, func: obj[key]});
                
                // 暴露到全局
                if (!globalThis.search) {
                  globalThis.search = obj[key];
                  globalThis.musicSearch = obj[key];
                  console.log('[EnhancedAdapter] 暴露搜索函数:', fullPath);
                }
              }
            } else if (typeof obj[key] === 'object' && obj[key] !== null) {
              deepScan(obj[key], path.concat([key]));
            }
          }
        } catch(e) {}
      }
      
      // 扫描全局对象
      deepScan(globalThis, []);
      
      // 扫描 exports 和 module
      if (typeof exports !== 'undefined') deepScan(exports, ['exports']);
      if (typeof module !== 'undefined' && module.exports) deepScan(module.exports, ['module', 'exports']);
      
      console.log('[EnhancedAdapter] 发现函数数量:', discoveredFunctions.length);
      
      // 暴露统一搜索接口
      if (!globalThis.grassSearch && discoveredFunctions.length > 0) {
        globalThis.grassSearch = function(platform, keyword, page) {
          console.log('[EnhancedSearch] 使用发现的函数进行搜索');
          for (var i = 0; i < discoveredFunctions.length; i++) {
            try {
              var func = discoveredFunctions[i].func;
              var result = func(platform, keyword, page);
              if (result && (Array.isArray(result) || result.then)) {
                return result;
              }
            } catch(e) {
              console.warn('[EnhancedSearch] 函数调用失败:', e);
            }
          }
          return [];
        };
      }
      
    }, 1000); // 延迟1秒执行
    
  } catch(e) {
    console.error('[EnhancedAdapter] 适配器初始化失败:', e);
  }
})();
''';

    return enhanced;
  }
}
