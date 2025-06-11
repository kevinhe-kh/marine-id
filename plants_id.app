import React, { useState, useEffect, useRef } from 'react';
import { Camera, Upload, CheckCircle, AlertCircle, Loader, Image as LucideImage, Leaf } from 'lucide-react';

// 主应用组件
export default function App() {
    // 状态管理
    const [imageSrc, setImageSrc] = useState(null); // 存储图片预览URL
    const [base64Image, setBase64Image] = useState(null); // 存储Base64格式的图片数据
    const [plantType, setPlantType] = useState('花卉'); // 当前选择的植物种类
    const [result, setResult] = useState(null); // 存储识别结果
    const [loading, setLoading] = useState(false); // 控制加载状态
    const [error, setError] = useState(null); // 存储错误信息
    const fileInputRef = useRef(null); // 文件输入框的引用

    // 植物种类列表 (已恢复到之前的数量)
    const plantTypes = [
        '花卉', '绿植', '多肉', '蔬菜', '水果', '树木', '草本植物', '蕨类植物'
    ];
    
    // 图片上传处理函数
    const handleImageUpload = (event) => {
        const file = event.target.files[0];
        if (file) {
            // 重置状态
            setResult(null);
            setError(null);
            
            const reader = new FileReader();
            reader.onload = (e) => {
                const fullBase64 = e.target.result;
                setImageSrc(fullBase64); // 用于在界面上预览图片
                // **关键修复**: 移除Base64头信息，只保留数据部分
                const pureBase64 = fullBase64.split(',')[1];
                setBase64Image(pureBase64);
            };
            reader.readAsDataURL(file);
        }
    };

    // 触发文件选择对话框
    const triggerFileSelect = () => {
        fileInputRef.current.click();
    };

    // 调用AI进行植物识别
    const identifyPlant = async () => {
        if (!base64Image) {
            setError("请先上传一张图片。");
            return;
        }

        setLoading(true);
        setResult(null);
        setError(null);

        try {
            const prompt = `你是一位植物识别专家。请根据这张图片，识别出这是什么植物。请重点判断它是否属于【${plantType}】。请提供以下信息：
1.  **植物名称**: (最可能的名称)
2.  **所属分类**: (是否属于用户选择的'${plantType}'分类)
3.  **形态特征**: (描述它的外观特点)
4.  **养护建议**: (简单的养护方法，如光照、浇水建议)`;

            const payload = {
                contents: [
                    {
                        role: "user",
                        parts: [
                            { text: prompt },
                            {
                                inlineData: {
                                    mimeType: "image/jpeg", // 假设图片为JPEG格式
                                    data: base64Image
                                }
                            }
                        ]
                    }
                ],
            };

            const apiKey = ""; // API密钥由环境提供
            const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`;

            const response = await fetch(apiUrl, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });
            
            if (!response.ok) {
                // 如果服务器响应不成功，则抛出错误
                const errorBody = await response.json();
                console.error("API 响应错误:", errorBody);
                throw new Error(`服务请求失败，状态码：${response.status}`);
            }

            const data = await response.json();

            if (data.candidates && data.candidates.length > 0 &&
                data.candidates[0].content && data.candidates[0].content.parts &&
                data.candidates[0].content.parts.length > 0) {
                const text = data.candidates[0].content.parts[0].text;
                setResult(text.replace(/\n/g, '<br />')); // 将换行符替换为HTML换行标签
            } else {
                // 处理AI没有返回有效内容的情况
                console.error("未找到有效的识别结果:", data);
                throw new Error("AI未能返回有效的识别结果，请检查图片或稍后重试。");
            }

        } catch (err) {
            console.error("识别过程中发生错误:", err);
            setError(err.message || "识别过程中发生未知错误，请检查网络连接或浏览器控制台获取更多信息。");
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="flex flex-col items-center justify-center min-h-screen bg-green-50 font-sans p-4">
            <div className="w-full max-w-2xl mx-auto bg-white rounded-2xl shadow-lg p-6 md:p-8">
                
                {/* 标题 */}
                <div className="text-center mb-6">
                    <h1 className="text-3xl md:text-4xl font-bold text-green-800 flex items-center justify-center">
                        <Leaf className="w-8 h-8 mr-3 text-green-600"/>
                        智能植物识别
                    </h1>
                    <p className="text-gray-500 mt-2">上传植物图片，AI将为您鉴定品种并提供养护建议</p>
                </div>

                {/* 图片上传区域 */}
                <div className="mb-6">
                    <div 
                        className="w-full h-64 border-2 border-dashed border-gray-300 rounded-lg flex items-center justify-center bg-gray-50 cursor-pointer hover:bg-gray-100 hover:border-green-400 transition-colors"
                        onClick={triggerFileSelect}
                    >
                        {imageSrc ? (
                            <img src={imageSrc} alt="上传的植物" className="max-h-full max-w-full object-contain rounded-md" />
                        ) : (
                            <div className="text-center text-gray-400">
                                <LucideImage className="w-16 h-16 mx-auto mb-2"/>
                                <p>点击此处上传图片</p>
                            </div>
                        )}
                    </div>
                    <input
                        type="file"
                        ref={fileInputRef}
                        onChange={handleImageUpload}
                        className="hidden"
                        accept="image/*"
                    />
                </div>

                {/* 植物种类选择 */}
                <div className="mb-6">
                    <label htmlFor="plant-type" className="block text-sm font-medium text-gray-700 mb-2">请选择您认为的植物种类：</label>
                    <select
                        id="plant-type"
                        value={plantType}
                        onChange={(e) => setPlantType(e.target.value)}
                        className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500 transition"
                    >
                        {plantTypes.map(type => (
                            <option key={type} value={type}>{type}</option>
                        ))}
                    </select>
                </div>
                
                {/* 操作按钮 */}
                <button
                    onClick={identifyPlant}
                    disabled={loading || !imageSrc}
                    className="w-full bg-green-600 text-white font-bold py-3 px-4 rounded-lg hover:bg-green-700 transition-transform transform hover:scale-105 disabled:bg-gray-400 disabled:cursor-not-allowed disabled:transform-none flex items-center justify-center"
                >
                    {loading ? (
                        <>
                            <Loader className="animate-spin w-5 h-5 mr-2" />
                            正在识别中...
                        </>
                    ) : (
                        <>
                            <Camera className="w-5 h-5 mr-2" />
                            开始识别
                        </>
                    )}
                </button>

                {/* 错误提示 */}
                {error && (
                    <div className="mt-4 p-4 bg-red-100 border border-red-400 text-red-700 rounded-lg flex items-center">
                        <AlertCircle className="w-5 h-5 mr-3 flex-shrink-0" />
                        <div>
                            <p className="font-bold">出错啦！</p>
                            <p>{error}</p>
                        </div>
                    </div>
                )}
                
                {/* 识别结果展示 */}
                {result && (
                    <div className="mt-6 p-5 bg-green-50 border border-green-200 rounded-lg">
                        <h2 className="text-xl font-semibold text-green-800 mb-3 flex items-center">
                            <CheckCircle className="w-6 h-6 mr-2 text-green-600" />
                            识别结果
                        </h2>
                        <div className="prose prose-sm max-w-none text-gray-700" dangerouslySetInnerHTML={{ __html: result }}></div>
                    </div>
                )}
            </div>
        </div>
    );
}

