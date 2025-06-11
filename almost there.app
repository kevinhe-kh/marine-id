import React, { useState, useEffect, useRef, createContext, useContext } from 'react';
import { initializeApp, getApps } from 'firebase/app';
import { getAuth, signInAnonymously, signInWithCustomToken, onAuthStateChanged } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

// =================================================================
// 1. CONSTANTS & TRANSLATIONS
// =================================================================
const translations = {
  'zh': { appName: '海洋生物识别器', uploadButton: '上传或拍摄照片', identifying: '识别中...', moreImagesButton: '更多图片', generatingImages: '正在生成图片...', noImageSelected: '没有选择图片。', apiError: 'API请求失败', recognitionFailed: '识别失败', noMarineLife: '未能识别出海洋生物。', errorDuringRecognition: '识别过程中发生错误', nameLabel: '名称', scientificNameLabel: '学名', descriptionLabel: '详细内容', languageName: '中文', translatingContent: '正在翻译...', overviewTab: '概览', funFusionTab: '欢乐图', introText: '上传一张海洋生物的图片，AI将为您识别它的身份。', sampleImagesTitle: '或试试这些示例：', enhancedLoadingTexts: ['AI正在深海中为您寻找更多同伴...', '我们的AI艺术家正在为您作画...', '稍等片刻，奇迹即将发生...'], uploadSceneButton: '上传背景图', startSynthesisButton: '开始合成', synthesizing: '合成中...', downloadButton: '下载', closeButton: '关闭', fileNameLabel: '文件名:', downloadAs: '下载为', errorAuthFailed: '认证失败', errorFirebaseInit: 'Firebase初始化失败', errorFirebaseConfigMissing: 'Firebase配置缺失，部分功能可能无法使用。', refreshButton: '换一批', synthesisPromptPlaceholder: '添加更多细节，例如：戴着一顶派对帽' },
  'en': { appName: 'Marine Life Identifier', uploadButton: 'Upload or Take a Photo', identifying: 'Identifying...', moreImagesButton: 'More Images', generatingImages: 'Generating Images...', noImageSelected: 'No image selected.', apiError: 'API request failed', recognitionFailed: 'Recognition failed', noMarineLife: 'Could not identify marine life.', errorDuringRecognition: 'Error during recognition', nameLabel: 'Name', scientificNameLabel: 'Scientific Name', descriptionLabel: 'Details', languageName: 'English', translatingContent: 'Translating...', overviewTab: 'Overview', funFusionTab: 'Fun Fusion', introText: 'Upload an image of a marine creature, and the AI will identify it for you.', sampleImagesTitle: 'Or try one of these samples:', enhancedLoadingTexts: ['The AI is searching the deep sea for more friends for you...', 'Our AI artist is painting for you...', 'Just a moment, magic is about to happen...'], uploadSceneButton: 'Upload Scene', startSynthesisButton: 'Start Fusion', synthesizing: 'Fusing images...', downloadButton: 'Download', closeButton: 'Close', fileNameLabel: 'Filename:', downloadAs: 'Download as', errorAuthFailed: 'Authentication failed', errorFirebaseInit: 'Firebase initialization failed', errorFirebaseConfigMissing: 'Firebase config is missing, some features may be unavailable.', refreshButton: 'Get New Batch', synthesisPromptPlaceholder: 'Add more details, e.g., wearing a party hat' },
};
const t = (key, locale) => translations[locale]?.[key] || translations['en'][key] || key;

const SAMPLE_IMAGES = [
    { src: 'https://images.unsplash.com/photo-1570481662207-7dc9f4701834?q=80&w=800', alt: 'Clownfish', 'zh-name': '小丑鱼', 'en-name': 'Clownfish', scientificName: 'Amphiprioninae', 'zh-desc': '小丑鱼是海葵鱼亚科鱼类的俗称，是一种热带咸水鱼。已知世界上有30多种，一种来自棘颊雀鲷属，其余来自双锯鱼属。', 'en-desc': 'Clownfish or anemonefish are fishes from the subfamily Amphiprioninae in the family Pomacentridae. Thirty species are recognized: one in the genus Premnas, while the remaining are in the genus Amphiprion.' },
    { src: 'https://images.unsplash.com/photo-1535498730771-e735b998cd64?q=80&w=800', alt: 'Jellyfish', 'zh-name': '水母', 'en-name': 'Jellyfish', scientificName: 'Medusozoa', 'zh-desc': '水母是刺胞动物门下、水母亚门动物的统称。它们是无脊椎动物，身体呈钟形或伞形，通常自由游动。', 'en-desc': 'Jellyfish and sea jellies are the informal common names given to the medusa-phase of certain gelatinous members of the subphylum Medusozoa, a major part of the phylum Cnidaria.' },
    { src: 'https://images.unsplash.com/photo-1601247387342-368054854694?q=80&w=800', alt: 'Sea Turtle', 'zh-name': '海龟', 'en-name': 'Sea Turtle', scientificName: 'Chelonioidea', 'zh-desc': '海龟是龟鳖目、海龟总科的海洋爬行动物。它们分布在除极地以外的世界各地的海洋中。', 'en-desc': 'Sea turtles are marine reptiles that inhabit all of the world\'s oceans except the Arctic. They belong to the superfamily Chelonioidea.' },
];

// =================================================================
// 2. API SERVICE LAYER
// =================================================================
const apiService = {
  async _fetch(url, payload) {
    const response = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(`API Error: ${response.status} - ${errorData.message || response.statusText}`);
    }
    return response.json();
  },
  
  async identifyImage(base64ImageData, fileType) {
    const promptText = `Strictly identify the marine life in this image. Respond in English with a single JSON object containing "name", "scientificName", and "description". Example: { "name": "Clownfish", "scientificName": "Amphiprioninae", "description": "..." }. If no marine life is identifiable, respond with { "error": "No marine life could be identified." }.`;
    const payload = {
      contents: [{ role: "user", parts: [{ text: promptText }, { inlineData: { mimeType: fileType, data: base64ImageData } }] }],
      generationConfig: { responseMimeType: "application/json", responseSchema: { type: "OBJECT", properties: { "name": { "type": "STRING" }, "scientificName": { "type": "STRING" }, "description": { "type": "STRING" }, "error": {"type": "STRING"} } } }
    };
    const result = await this._fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=`, payload);
    const text = result?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) throw new Error("Invalid API response structure from Gemini.");
    return JSON.parse(text);
  },

  async translateText(text, targetLocale) {
    if (!text || targetLocale === 'en') return text;
    const prompt = `Translate the following English text to ${t('languageName', targetLocale)}. Provide only the translated text, without any introductory phrases or quotes. Original text: "${text}"`;
    const payload = { contents: [{ role: "user", parts: [{ text: prompt }] }] };
    const result = await this._fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=`, payload);
    return result?.candidates?.[0]?.content?.parts?.[0]?.text.trim() || text;
  },

  async generateImages(prompt) {
    const payload = { instances: [{ prompt: `A high-quality, realistic photograph of a ${prompt}` }], parameters: { "sampleCount": 4 } };
    const result = await this._fetch(`https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-002:predict?key=`, payload);
    return result.predictions?.map(p => `data:image/png;base64,${p.bytesBase64Encoded}`) || [];
  },
  
  // **MODIFIED**: Now accepts a userPrompt
  async synthesizeImage(sceneFile, subjectName, userPrompt) {
    const sceneBase64 = await new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.readAsDataURL(sceneFile);
        reader.onload = () => resolve(reader.result.split(',')[1]);
        reader.onerror = reject;
    });

    const descriptionPrompt = "Briefly describe this scene for an image generation AI. Focus on the environment, lighting, and style. Example: 'a vibrant coral reef with sun rays filtering through the water'.";
    const visionPayload = { contents: [{ role: "user", parts: [{ text: descriptionPrompt }, { inlineData: { mimeType: sceneFile.type, data: sceneBase64 } }] }] };
    const visionResult = await this._fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=`, visionPayload);
    const sceneDescription = visionResult.candidates[0].content.parts[0].text;

    // **MODIFIED**: New prompt combines subject, user input, and scene description
    const synthesisPrompt = `Synthesize a high-quality, realistic photograph. The main subject is a ${subjectName} ${userPrompt ? `that is ${userPrompt}` : ''}. Integrate this subject into the following scene: "${sceneDescription}". Ensure lighting, shadows, and perspective match the scene.`;
    
    const synthesisPayload = { instances: [{ prompt: synthesisPrompt }], parameters: { "sampleCount": 1 } };
    const synthesisResult = await this._fetch(`https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-002:predict?key=`, synthesisPayload);
    
    if (synthesisResult.predictions?.length > 0) {
        return `data:image/png;base64,${synthesisResult.predictions[0].bytesBase64Encoded}`;
    }
    throw new Error("Image synthesis failed to return a result.");
  }
};

// =================================================================
// 3. CONTEXT FOR STATE MANAGEMENT
// =================================================================
const AppContext = createContext();

const AppProvider = ({ children }) => {
  const [locale, setLocale] = useState('zh');
  const [loadingStates, setLoadingStates] = useState({ identifying: false, translating: false, generatingImages: false, synthesizing: false });
  const [recognitionResult, setRecognitionResult] = useState(null);
  const [translatedDisplayContent, setTranslatedDisplayContent] = useState({ name: '', description: '' });
  const [moreImages, setMoreImages] = useState([]);
  const [imagePreview, setImagePreview] = useState(null);
  const [errorMessage, setErrorMessage] = useState('');
  const [isAuthReady, setIsAuthReady] = useState(false);
  const [activeTab, setActiveTab] = useState('overview');
  const [modalImage, setModalImage] = useState(null);
  const [synthesisSceneFile, setSynthesisSceneFile] = useState(null);
  const [synthesisScenePreview, setSynthesisScenePreview] = useState(null);
  const [synthesisResultImage, setSynthesisResultImage] = useState(null);
  // **NEW**: State for the Fun Fusion prompt
  const [synthesisPromptText, setSynthesisPromptText] = useState('');

  const fileInputRef = useRef(null);
  const sceneFileInputRef = useRef(null);
  const setLoading = (key, value) => setLoadingStates(prev => ({ ...prev, [key]: value }));
  const isBusy = Object.values(loadingStates).some(Boolean);

  useEffect(() => {
    try {
      if (typeof __firebase_config === 'undefined' || !__firebase_config) {
        console.warn("Firebase config `__firebase_config` is missing.");
        setErrorMessage('errorFirebaseConfigMissing'); setIsAuthReady(true); return;
      }
      const firebaseConfig = JSON.parse(__firebase_config);
      if (getApps().length === 0) initializeApp(firebaseConfig);
      const auth = getAuth();
      const unsubscribe = onAuthStateChanged(auth, async (user) => {
        if (!user) {
          try {
            const token = typeof __initial_auth_token !== 'undefined' ? __initial_auth_token : null;
            if (auth.currentUser === null) await (token ? signInWithCustomToken(auth, token) : signInAnonymously(auth));
          } catch (error) { console.error("Authentication Error:", error); setErrorMessage('errorAuthFailed'); }
        }
        setIsAuthReady(true);
      });
      return () => unsubscribe();
    } catch (error) { console.error("Firebase Init Error:", error); setErrorMessage('errorFirebaseInit'); setIsAuthReady(true); }
  }, []);

  useEffect(() => {
    const translate = async () => {
      if (!recognitionResult || recognitionResult.error) {
        setTranslatedDisplayContent({ name: '', description: '' }); return;
      }
      setTranslatedDisplayContent({ name: recognitionResult.name, description: recognitionResult.description });
      if (locale === 'en') return;
      setLoading('translating', true);
      try {
        const [translatedName, translatedDescription] = await Promise.all([
          apiService.translateText(recognitionResult.name, locale),
          apiService.translateText(recognitionResult.description, locale)
        ]);
        setTranslatedDisplayContent({ name: translatedName, description: translatedDescription });
      } catch (error) { 
        console.error("Translation Error:", error);
        setTranslatedDisplayContent({ name: recognitionResult.name, description: recognitionResult.description });
      } finally { setLoading('translating', false); }
    };
    translate();
  }, [locale, recognitionResult]);
  
  const resetState = (clearImage = true) => {
    setRecognitionResult(null); setErrorMessage(''); setMoreImages([]); setTranslatedDisplayContent({ name: '', description: '' });
    if(clearImage) setImagePreview(null);
    setActiveTab('overview'); setSynthesisSceneFile(null); setSynthesisScenePreview(null); setSynthesisResultImage(null); setSynthesisPromptText('');
  };

  const toBase64 = (file) => new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => resolve(reader.result.split(',')[1]);
    reader.onerror = reject; reader.readAsDataURL(file);
  });
  
  // **MODIFIED**: Now handles automatic image generation on success
  const handleGenerateImages = async (subjectNameOverride) => {
      const subject = subjectNameOverride || recognitionResult?.name;
      if (!subject) return;
      setMoreImages([]); // Clear old images
      setLoading('generatingImages', true);
      try {
          const images = await apiService.generateImages(subject);
          setMoreImages(images);
      } catch (error) { 
          console.error("Image Generation Error:", error);
          setErrorMessage(error.message); 
      } finally { setLoading('generatingImages', false); }
  };
  
  // **MODIFIED**: Triggers automatic image generation
  const handleIdentify = async (file) => {
    resetState();
    if (!file) { setErrorMessage(t('noImageSelected', locale)); return; }
    setLoading('identifying', true);
    setImagePreview(URL.createObjectURL(file));
    try {
      const base64ImageData = await toBase64(file);
      const result = await apiService.identifyImage(base64ImageData, file.type);
      setRecognitionResult(result);
      if (result.error) {
        setErrorMessage(t(result.error, locale));
      } else {
        // **NEW**: Automatically generate images after successful identification
        handleGenerateImages(result.name); 
      }
    } catch (error) { 
      console.error("Identification Error:", error);
      setErrorMessage(`${t('errorDuringRecognition', locale)}: ${error.message}`); 
    } finally { setLoading('identifying', false); }
  };
  
  // **MODIFIED**: Now uses prompt text from state
  const handleSynthesize = async () => {
    if(!synthesisSceneFile || !recognitionResult?.name) return;
    setLoading('synthesizing', true);
    setSynthesisResultImage(null);
    try {
      const resultImg = await apiService.synthesizeImage(synthesisSceneFile, recognitionResult.name, synthesisPromptText);
      setSynthesisResultImage(resultImg);
    } catch(error) { 
      console.error("Synthesis Error:", error);
      setErrorMessage(error.message); 
    } finally { setLoading('synthesizing', false); }
  };

  const value = {
    locale, setLocale, loadingStates, isBusy, recognitionResult, translatedDisplayContent, moreImages, imagePreview, errorMessage, setErrorMessage, isAuthReady, activeTab, setActiveTab, modalImage, setModalImage, synthesisSceneFile, setSynthesisSceneFile, synthesisScenePreview, setSynthesisScenePreview, synthesisResultImage, synthesisPromptText, setSynthesisPromptText,
    fileInputRef, sceneFileInputRef, handleIdentify, handleGenerateImages, handleSynthesize, resetState, setLoading
  };

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
};

const useAppContext = () => useContext(AppContext);

// =================================================================
// 4. CHILD COMPONENTS
// =================================================================

const EnhancedLoadingSpinner = ({ loadingKey, locale }) => {
    const [text, setText] = useState('');
    useEffect(() => {
        const loadingTexts = translations[locale]?.enhancedLoadingTexts || translations['en']?.enhancedLoadingTexts || [];
        if (loadingTexts.length === 0) return;
        setText(loadingTexts[0]);
        const intervalId = setInterval(() => {
            setText(currentText => {
                const currentIndex = loadingTexts.indexOf(currentText);
                return loadingTexts[(currentIndex + 1) % loadingTexts.length];
            });
        }, 2500);
        return () => clearInterval(intervalId);
    }, [locale]);
    return (
        <span className="flex items-center justify-center animate-pulse">
            <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle><path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
            <span>{text || t(loadingKey, locale)}</span>
        </span>
    );
};

const LanguageSelector = () => {
  const { locale, setLocale, isBusy } = useAppContext();
  const languages = [{ code: 'zh', flag: '🇨🇳', name: '中文' }, { code: 'en', flag: '🇺🇸', name: 'English' }];
  return (
    <div className="flex justify-center gap-4 mb-6">
      {languages.map((lang) => (<button key={lang.code} onClick={() => setLocale(lang.code)} disabled={isBusy} aria-label={`Switch to ${lang.name}`} className={`p-2 rounded-full text-2xl sm:text-3xl transition-all transform hover:scale-110 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed ${locale === lang.code ? 'ring-2 ring-blue-500' : 'ring-1 ring-transparent'}`} title={lang.name}>{lang.flag}</button>))}
    </div>
  );
};

const ImageUploader = () => {
  const { locale, loadingStates, isBusy, isAuthReady, fileInputRef, handleIdentify, setErrorMessage } = useAppContext();
  const handleChange = (e) => {
    setErrorMessage('');
    if (e.target.files && e.target.files[0]) handleIdentify(e.target.files[0]);
  }
  return (
    <>
      <input id="image-upload" type="file" accept="image/*" onChange={handleChange} className="hidden" ref={fileInputRef} onClick={(e) => { e.target.value = null }}/>
      <button onClick={() => fileInputRef.current.click()} disabled={isBusy || !isAuthReady} className="w-full py-3 px-6 rounded-xl text-white font-bold text-lg transition-all duration-300 transform shadow-lg hover:shadow-xl disabled:shadow-none disabled:transform-none bg-gradient-to-r from-teal-500 to-blue-600 hover:scale-105 disabled:bg-gray-400 disabled:cursor-not-allowed" aria-label={t('uploadButton', locale)}>
        {loadingStates.identifying ? <EnhancedLoadingSpinner loadingKey="identifying" locale={locale}/> : t('uploadButton', locale)}
      </button>
    </>
  );
};

const EmptyState = () => {
    const { locale, isBusy, handleIdentify } = useAppContext();
    const handleSampleClick = async (sample) => {
        try {
            const response = await fetch(sample.src); const blob = await response.blob();
            const file = new File([blob], `${sample.alt}.jpg`, { type: blob.type }); handleIdentify(file);
        } catch (error) { console.error("Failed to fetch sample image:", error); }
    };
    return (
        <div className="text-center mt-8 py-4">
            <p className="text-gray-600 mb-6 text-base">{t('introText', locale)}</p>
            <h3 className="text-lg font-semibold text-gray-800 mb-4">{t('sampleImagesTitle', locale)}</h3>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                {SAMPLE_IMAGES.map(sample => (<button key={sample.alt} disabled={isBusy} onClick={() => handleSampleClick(sample)} className="cursor-pointer group disabled:cursor-not-allowed text-left"><img src={sample.src} alt={sample.alt} className="rounded-lg shadow-md group-hover:shadow-xl group-hover:scale-105 transition-all duration-300 w-full h-40 object-cover group-disabled:opacity-60" /><p className="text-sm font-medium text-gray-700 mt-2 group-hover:text-blue-600">{sample[`${locale}-name`]}</p></button>))}
            </div>
        </div>
    );
};

const ResultTabs = () => {
    const { locale, activeTab, setActiveTab, isBusy } = useAppContext();
    const tabs = [ {id: 'overview', label: t('overviewTab', locale)}, {id: 'moreImages', label: t('moreImagesButton', locale)}, {id: 'funFusion', label: t('funFusionTab', locale)} ];
    return (
        <div className="mt-6">
            <div className="border-b border-gray-200">
                <nav className="-mb-px flex space-x-4 sm:space-x-6" aria-label="Tabs">
                    {tabs.map(tab => (<button key={tab.id} onClick={() => setActiveTab(tab.id)} disabled={isBusy} className={`${activeTab === tab.id ? 'border-blue-500 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'} whitespace-nowrap py-3 px-1 border-b-2 font-medium text-sm sm:text-base transition-colors disabled:opacity-50`}>{tab.label}</button>))}
                </nav>
            </div>
            <div className="py-4 bg-white rounded-b-lg">
                 {activeTab === 'overview' && <OverviewTab />}
                 {activeTab === 'moreImages' && <MoreImagesTab />}
                 {activeTab === 'funFusion' && <FunFusionTab />}
            </div>
        </div>
    );
};

const SkeletonLoader = () => (
    <div className="space-y-4 animate-pulse"><div className="h-4 bg-gray-200 rounded w-3/4"></div><div className="h-4 bg-gray-200 rounded w-1/2"></div><div className="space-y-2 pt-2"><div className="h-4 bg-gray-200 rounded w-full"></div><div className="h-4 bg-gray-200 rounded w-full"></div><div className="h-4 bg-gray-200 rounded w-5/6"></div></div></div>
);

// **MODIFIED**: Removed the "More Images" button
const OverviewTab = () => {
    const { locale, loadingStates, recognitionResult, translatedDisplayContent } = useAppContext();
    return (
        <div className="p-4 bg-blue-50 rounded-lg">
            {loadingStates.translating && !translatedDisplayContent.name ? <SkeletonLoader /> : 
            (<div className="space-y-3">
                <div><strong className="font-semibold text-gray-800">{t('nameLabel', locale)}:</strong> <span className="text-gray-700">{translatedDisplayContent.name}</span></div>
                <div><strong className="font-semibold text-gray-800">{t('scientificNameLabel', locale)}:</strong> <span className="text-gray-700 italic">{recognitionResult.scientificName}</span></div>
                <div>
                    <p className="font-semibold text-gray-800 mb-1">{t('descriptionLabel', locale)}:</p>
                    <p className="text-gray-700 whitespace-pre-wrap leading-relaxed">{translatedDisplayContent.description}</p>
                </div>
            </div>)
            }
        </div>
    );
};

// **MODIFIED**: Added refresh button
const MoreImagesTab = () => {
    const { locale, moreImages, setModalImage, loadingStates, handleGenerateImages, isBusy } = useAppContext();
    
    if (loadingStates.generatingImages && moreImages.length === 0) {
        return (
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 animate-pulse">
                {[...Array(4)].map((_, i) => <div key={i} className="w-full h-32 bg-gray-200 rounded-lg"></div>)}
            </div>
        );
    }

    return (
        <div className="space-y-4">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                {moreImages.map((src, i) => <img key={i} src={src} onClick={() => setModalImage(src)} alt={`Generated marine life ${i+1}`} className="w-full h-full object-cover rounded-lg shadow-md cursor-pointer transition-transform hover:scale-105" />)}
            </div>
            {moreImages.length > 0 && (
                <div className="flex justify-center">
                    <button onClick={() => handleGenerateImages()} disabled={isBusy} className="py-2 px-6 rounded-lg text-white font-semibold transition-colors bg-purple-500 hover:bg-purple-600 disabled:bg-gray-400">
                         {loadingStates.generatingImages ? <EnhancedLoadingSpinner loadingKey="generatingImages" locale={locale}/> : t('refreshButton', locale)}
                    </button>
                </div>
            )}
        </div>
    );
};

// **MODIFIED**: Added prompt input, removed result label
const FunFusionTab = () => {
    const { locale, isBusy, loadingStates, sceneFileInputRef, synthesisScenePreview, setSynthesisScenePreview, setSynthesisSceneFile, handleSynthesize, synthesisResultImage, setModalImage, setErrorMessage, synthesisPromptText, setSynthesisPromptText } = useAppContext();
    
    const handleFileChange = (e) => {
        if(e.target.files && e.target.files[0]) {
            setErrorMessage(''); const file = e.target.files[0];
            setSynthesisSceneFile(file); setSynthesisScenePreview(URL.createObjectURL(file));
        }
    };

    return (
        <div className="space-y-4 text-center">
            <input type="file" accept="image/*" onChange={handleFileChange} className="hidden" ref={sceneFileInputRef} onClick={(e) => { e.target.value = null }}/>
            {!synthesisScenePreview && (
                <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center cursor-pointer hover:border-green-500 hover:bg-green-50 transition-colors" onClick={() => sceneFileInputRef.current.click()}>
                    <svg className="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48" aria-hidden="true"><path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" /></svg>
                    <p className="mt-2 block text-sm font-medium text-gray-900">{t('uploadSceneButton', locale)}</p>
                    <p className="text-xs text-gray-500">上传一张风景图片作为背景</p>
                </div>
            )}
            {synthesisScenePreview && (
                <div className="p-2 border rounded-lg bg-gray-100 inline-block relative">
                    <img src={synthesisScenePreview} alt="Scene preview" className="max-w-xs h-auto rounded-md" />
                    <button onClick={() => sceneFileInputRef.current.click()} className="absolute top-2 right-2 bg-white bg-opacity-75 rounded-full p-1.5 text-gray-700 hover:bg-opacity-100"><svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path d="M17.414 2.586a2 2 0 00-2.828 0L7 10.172V13h2.828l7.586-7.586a2 2 0 000-2.828z" /><path fillRule="evenodd" d="M2 6a2 2 0 012-2h4a1 1 0 010 2H4v10h10v-4a1 1 0 112 0v4a2 2 0 01-2 2H4a2 2 0 01-2-2V6z" clipRule="evenodd" /></svg></button>
                </div>
            )}
            {/* **NEW**: Prompt input field */}
            <textarea value={synthesisPromptText} onChange={(e) => setSynthesisPromptText(e.target.value)} placeholder={t('synthesisPromptPlaceholder', locale)} className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 transition-colors" rows="2"></textarea>
            
            <button onClick={handleSynthesize} disabled={isBusy || !synthesisScenePreview} className="w-full py-3 px-6 rounded-xl text-white font-bold bg-gradient-to-r from-cyan-500 to-blue-500 hover:scale-105 transition-transform disabled:bg-gray-400 disabled:transform-none disabled:cursor-not-allowed">
                {loadingStates.synthesizing ? <EnhancedLoadingSpinner loadingKey="synthesizing" locale={locale}/> : t('startSynthesisButton', locale)}
            </button>
            {synthesisResultImage && (
                // **MODIFIED**: Removed the "合成结果" h3 tag
                <div className="mt-4">
                    <img src={synthesisResultImage} onClick={() => setModalImage(synthesisResultImage)} alt="Fused image" className="w-full h-auto object-cover rounded-lg shadow-lg cursor-pointer transition-transform hover:scale-105" />
                </div>
            )}
        </div>
    );
};

const ImageModal = () => {
    const { locale, modalImage, setModalImage, recognitionResult } = useAppContext();
    const [filename, setFilename] = useState('');
    useEffect(() => {
        if(recognitionResult?.name) setFilename(recognitionResult.name.replace(/\s+/g, '_').toLowerCase());
    }, [recognitionResult]);
    if (!modalImage) return null;
    const handleDownload = () => {
        const link = document.createElement('a');
        link.href = modalImage; link.download = `${filename || 'image'}.png`;
        document.body.appendChild(link); link.click(); document.body.removeChild(link);
    };
    return (
        <div className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50 p-4" onClick={() => setModalImage(null)} aria-modal="true" role="dialog">
            <div className="bg-white rounded-lg shadow-2xl p-4 sm:p-6 max-w-4xl w-full relative animate-scale-in" onClick={(e) => e.stopPropagation()}>
                <button onClick={() => setModalImage(null)} className="absolute -top-3 -right-3 bg-white rounded-full p-2 z-10 shadow-lg text-gray-700 hover:text-red-500 transition-colors"><svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg></button>
                <img src={modalImage} alt="Enlarged view" className="w-full h-auto object-contain rounded-lg max-h-[70vh]" />
                <div className="mt-4 flex flex-col sm:flex-row-reverse sm:items-center sm:gap-4 space-y-3 sm:space-y-0">
                     <button onClick={handleDownload} className="w-full sm:w-auto py-2 px-6 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors shadow-md hover:shadow-lg">{t('downloadButton', locale)}</button>
                     <div className="flex-grow flex items-center gap-2">
                        <label htmlFor="filename" className="text-sm font-medium text-gray-700 whitespace-nowrap">{t('fileNameLabel', locale)}</label>
                        <input id="filename" type="text" value={filename} onChange={(e) => setFilename(e.target.value)} className="w-full px-2 py-1.5 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500" placeholder="e.g., clownfish_in_coral"/>
                        <span className="text-gray-500 text-sm">.png</span>
                     </div>
                </div>
            </div>
        </div>
    );
};

// =================================================================
// 5. MAIN APP COMPONENT
// =================================================================
const AppUI = () => {
  const { locale, imagePreview, recognitionResult, errorMessage, setErrorMessage } = useAppContext();
  const hasResult = recognitionResult && !recognitionResult.error;
  return (
    <div className="min-h-screen bg-gray-50 flex flex-col items-center p-4 font-sans">
      <style>{`@keyframes scale-in { 0% { transform: scale(0.95); opacity: 0; } 100% { transform: scale(1); opacity: 1; } } .animate-scale-in { animation: scale-in 0.3s ease-out forwards; }`}</style>
      <div className="bg-white rounded-2xl shadow-xl p-6 sm:p-8 max-w-2xl w-full my-8 border border-gray-200">
        <h1 className="text-3xl sm:text-4xl font-extrabold text-center text-gray-800 mb-2">{t('appName', locale)}</h1>
        <LanguageSelector />
        <div className="mt-6"><ImageUploader /></div>
        {errorMessage && <div className="mt-6 p-4 bg-red-100 border-l-4 border-red-500 text-red-800 rounded-r-lg flex justify-between items-center"><span>{t(errorMessage, locale)}</span><button onClick={() => setErrorMessage('')} className="font-bold text-red-800 hover:text-red-600 text-2xl leading-none">&times;</button></div>}
        {recognitionResult?.error && <div className="mt-6 p-4 bg-yellow-100 border-l-4 border-yellow-500 text-yellow-800 rounded-r-lg text-center">{recognitionResult.error}</div>}
        {imagePreview && <div className="mt-6 p-2 border border-gray-200 rounded-xl bg-gray-50 shadow-inner"><img src={imagePreview} alt="Uploaded preview" className="max-w-full h-auto rounded-lg mx-auto" /></div>}
        {hasResult ? <ResultTabs /> : <EmptyState />}
        <ImageModal />
      </div>
    </div>
  );
};

export default function App() {
  return ( <AppProvider> <AppUI /> </AppProvider> );
}

