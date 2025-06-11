import React, { useState, useEffect, useRef, createContext, useContext } from 'react';
import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously, signInWithCustomToken, onAuthStateChanged } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

// =================================================================
// 1. CONSTANTS & TRANSLATIONS
// =================================================================
const translations = {
  'zh': { appName: '海洋生物识别器', uploadButton: '上传或拍摄照片', identifying: '识别中...', moreImagesButton: '更多图片', generatingImages: '正在生成图片...', noImageSelected: '没有选择图片。', apiError: 'API请求失败', recognitionFailed: '识别失败', noMarineLife: '未能识别出海洋生物。', errorDuringRecognition: '识别过程中发生错误', nameLabel: '名称', scientificNameLabel: '学名', descriptionLabel: '详细内容', languageName: '中文', translatingContent: '正在翻译...', overviewTab: '概览', funFusionTab: '欢乐图', introText: '上传一张海洋生物的图片，AI将为您识别它的身份。', sampleImagesTitle: '或试试这些示例：', enhancedLoadingTexts: ['AI正在深海中为您寻找更多同伴...', '我们的AI艺术家正在为您作画...', '稍等片刻，奇迹即将发生...'], uploadSceneButton: '上传背景图', startSynthesisButton: '开始合成', synthesizing: '合成中...', downloadButton: '下载', closeButton: '关闭', fileNameLabel: '文件名:', downloadAs: '下载为', errorAuthFailed: '认证失败', errorFirebaseInit: 'Firebase初始化失败' },
  'en': { appName: 'Marine Life Identifier', uploadButton: 'Upload or Take a Photo', identifying: 'Identifying...', moreImagesButton: 'More Images', generatingImages: 'Generating Images...', noImageSelected: 'No image selected.', apiError: 'API request failed', recognitionFailed: 'Recognition failed', noMarineLife: 'Could not identify marine life.', errorDuringRecognition: 'Error during recognition', nameLabel: 'Name', scientificNameLabel: 'Scientific Name', descriptionLabel: 'Details', languageName: 'English', translatingContent: 'Translating...', overviewTab: 'Overview', funFusionTab: 'Fun Fusion', introText: 'Upload an image of a marine creature, and the AI will identify it for you.', sampleImagesTitle: 'Or try one of these samples:', enhancedLoadingTexts: ['The AI is searching the deep sea for more friends for you...', 'Our AI artist is painting for you...', 'Just a moment, magic is about to happen...'], uploadSceneButton: 'Upload Scene', startSynthesisButton: 'Start Fusion', synthesizing: 'Fusing images...', downloadButton: 'Download', closeButton: 'Close', fileNameLabel: 'Filename:', downloadAs: 'Download as', errorAuthFailed: 'Authentication failed', errorFirebaseInit: 'Firebase initialization failed' },
};
const t = (key, locale) => translations[locale]?.[key] || translations['en'][key] || key;

const SAMPLE_IMAGES = [
    { src: 'https://images.unsplash.com/photo-1570481662207-7dc9f4701834?q=80&w=800', alt: 'Clownfish', 'zh-name': '小丑鱼', 'en-name': 'Clownfish', scientificName: 'Amphiprioninae', 'zh-desc': '小丑鱼是海葵鱼亚科鱼类的俗称，是一种热带咸水鱼。已知世界上有30多种，一种来自棘颊雀鲷属，其余来自双锯鱼属。', 'en-desc': 'Clownfish or anemonefish are fishes from the subfamily Amphiprioninae in the family Pomacentridae. Thirty species are recognized: one in the genus Premnas, while the remaining are in the genus Amphiprion.' },
    { src: 'https://images.unsplash.com/photo-1535498730771-e735b998cd64?q=80&w=800', alt: 'Jellyfish', 'zh-name': '水母', 'en-name': 'Jellyfish', scientificName: 'Medusozoa', 'zh-desc': '水母是刺胞动物门下、水母亚门动物的统称。它们是无脊椎动物，身体呈钟形或伞形，通常自由游动。', 'en-desc': 'Jellyfish and sea jellies are the informal common names given to the medusa-phase of certain gelatinous members of the subphylum Medusozoa, a major part of the phylum Cnidaria.' },
    { src: 'https://images.unsplash.com/photo-1601247387342-368054854694?q=80&w=800', alt: 'Sea Turtle', 'zh-name': '海龟', 'en-name': 'Sea Turtle', scientificName: 'Chelonioidea', 'zh-desc': '海龟是龟鳖目、海龟总科的海洋爬行动物。它们分布在除极地以外的世界各地的海洋中。', 'en-desc': 'Sea turtles are marine reptiles that inhabit all of the world\'s oceans except the Arctic. They belong to the superfamily Chelonioidea.' },
];

// =================================================================
// 2. API SERVICE LAYER (Abstraction for network requests)
// =================================================================
const apiService = {
  async _fetch(url, payload) {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(`API Error: ${response.status} - ${errorData.message || response.statusText}`);
    }
    return response.json();
  },
  
  async identifyImage(base64ImageData, fileType) {
    const promptText = `Identify the marine life in this image. Provide its common name, scientific name, and a brief description. All output must be in English. Return a strict JSON format: { "name": "...", "scientificName": "...", "description": "..." }. If no marine life is found, return { "error": "No marine life could be identified." }.`;
    const payload = {
      contents: [{ role: "user", parts: [{ text: promptText }, { inlineData: { mimeType: fileType, data: base64ImageData } }] }],
      generationConfig: { responseMimeType: "application/json", responseSchema: { type: "OBJECT", properties: { "name": { "type": "STRING" }, "scientificName": { "type": "STRING" }, "description": { "type": "STRING" }, "error": {"type": "STRING"} } } }
    };
    const result = await this._fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=`, payload);
    return JSON.parse(result.candidates[0].content.parts[0].text);
  },

  async translateText(text, targetLocale) {
    if (!text || targetLocale === 'en') return text;
    const prompt = `Translate the following English text to ${t('languageName', targetLocale)}. Provide only the translated text. Original text: "${text}"`;
    const payload = { contents: [{ role: "user", parts: [{ text: prompt }] }] };
    const result = await this._fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=`, payload);
    return result.candidates[0].content.parts[0].text.trim();
  },

  async generateImages(prompt) {
    const payload = { instances: [{ prompt }], parameters: { "sampleCount": 4 } };
    const result = await this._fetch(`https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-002:predict?key=`, payload);
    return result.predictions?.map(p => `data:image/png;base64,${p.bytesBase64Encoded}`) || [];
  },
  
  async synthesizeImage(sceneFile, subjectName) {
    const sceneBase64 = await new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.readAsDataURL(sceneFile);
        reader.onload = () => resolve(reader.result.split(',')[1]);
        reader.onerror = reject;
    });

    const descriptionPrompt = "Briefly describe this scene for an image generation AI. Focus on the environment. Example: 'a sandy ocean floor with sun rays'.";
    const visionPayload = { contents: [{ role: "user", parts: [{ text: descriptionPrompt }, { inlineData: { mimeType: sceneFile.type, data: sceneBase64 } }] }] };
    const visionResult = await this._fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=`, visionPayload);
    const sceneDescription = visionResult.candidates[0].content.parts[0].text;

    const synthesisPrompt = `A high-quality, realistic photograph of a ${subjectName} seamlessly integrated into this scene: ${sceneDescription}.`;
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
  const [recognitionResult, setRecognitionResult] = useState(null); // Canonical ENGLISH result
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

  const fileInputRef = useRef(null);
  const sceneFileInputRef = useRef(null);

  const setLoading = (key, value) => setLoadingStates(prev => ({ ...prev, [key]: value }));
  const isBusy = Object.values(loadingStates).some(Boolean);

  useEffect(() => {
    try {
      const firebaseConfig = typeof __firebase_config !== 'undefined' ? JSON.parse(__firebase_config) : {};
      initializeApp(firebaseConfig);
      const auth = getAuth();
      onAuthStateChanged(auth, async (user) => {
        if (!user) {
          try {
            const token = typeof __initial_auth_token !== 'undefined' ? __initial_auth_token : null;
            await (token ? signInWithCustomToken(auth, token) : signInAnonymously(auth));
          } catch (error) { setErrorMessage(t('errorAuthFailed', locale)); }
        }
        setIsAuthReady(true);
      });
    } catch (error) { setErrorMessage(t('errorFirebaseInit', locale)); }
  }, [locale]);

  useEffect(() => {
    const translate = async () => {
      if (!recognitionResult || recognitionResult.error) {
        setTranslatedDisplayContent({ name: '', description: '' });
        return;
      }
      setLoading('translating', true);
      try {
        const [name, description] = await Promise.all([
          apiService.translateText(recognitionResult.name, locale),
          apiService.translateText(recognitionResult.description, locale)
        ]);
        setTranslatedDisplayContent({ name, description });
      } catch (error) { setTranslatedDisplayContent({ name: recognitionResult.name, description: recognitionResult.description }); }
      finally { setLoading('translating', false); }
    };
    translate();
  }, [locale, recognitionResult]);
  
  const resetState = () => {
    setRecognitionResult(null);
    setErrorMessage('');
    setMoreImages([]);
    setTranslatedDisplayContent({ name: '', description: '' });
    setImagePreview(null);
    setActiveTab('overview');
    setSynthesisSceneFile(null);
    setSynthesisScenePreview(null);
    setSynthesisResultImage(null);
  };

  const toBase64 = (file) => new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => resolve(reader.result.split(',')[1]);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });

  const handleIdentify = async (file) => {
    resetState();
    if (!file) { setErrorMessage(t('noImageSelected', locale)); return; }
    setLoading('identifying', true);
    setImagePreview(URL.createObjectURL(file));
    try {
      const base64ImageData = await toBase64(file);
      const result = await apiService.identifyImage(base64ImageData, file.type);
      setRecognitionResult(result);
      if (result.error) setErrorMessage(result.error);
    } catch (error) { setErrorMessage(`${t('errorDuringRecognition', locale)}: ${error.message}`); }
    finally { setLoading('identifying', false); }
  };
  
  const handleGenerateImages = async () => {
      if (!recognitionResult || recognitionResult.error) return;
      setLoading('generatingImages', true);
      try {
          const images = await apiService.generateImages(recognitionResult.name);
          setMoreImages(images);
          setActiveTab('moreImages');
      } catch (error) { setErrorMessage(error.message); } 
      finally { setLoading('generatingImages', false); }
  };
  
  const handleSynthesize = async () => {
    if(!synthesisSceneFile) return;
    setLoading('synthesizing', true);
    try {
      const resultImg = await apiService.synthesizeImage(synthesisSceneFile, recognitionResult.name);
      setSynthesisResultImage(resultImg);
    } catch(error) { setErrorMessage(error.message); }
    finally { setLoading('synthesizing', false); }
  };

  const value = {
    locale, setLocale, loadingStates, isBusy, recognitionResult, translatedDisplayContent, moreImages, imagePreview, errorMessage, isAuthReady, activeTab, setActiveTab, modalImage, setModalImage, synthesisSceneFile, setSynthesisSceneFile, synthesisScenePreview, setSynthesisScenePreview, synthesisResultImage,
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
    const texts = t('enhancedLoadingTexts', locale);

    useEffect(() => {
        if (!texts || texts.length === 0) return;
        setText(texts[0]);
        const interval = setInterval(() => {
            setText(prev => {
                const currentIndex = texts.indexOf(prev);
                return texts[(currentIndex + 1) % texts.length];
            });
        }, 2000);
        return () => clearInterval(interval);
    }, [texts]);

    return (<span className="flex items-center justify-center"><svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle><path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>{text || t(loadingKey, locale)}</span>);
};

const LanguageSelector = () => {
  const { locale, setLocale } = useAppContext();
  const languages = [{ code: 'zh', flag: '🇨🇳' }, { code: 'en', flag: '🇺🇸' }];
  
  return ( <div className="flex flex-wrap justify-center gap-2 sm:gap-3 mb-6"> {languages.map((lang) => (<button key={lang.code} onClick={() => setLocale(lang.code)} aria-label={`Switch to ${t('languageName', lang.code)}`} className={`p-1.5 rounded-full text-2xl transition-transform transform hover:scale-110 ${locale === lang.code ? 'ring-2 ring-blue-500' : ''}`} title={t('languageName', lang.code)}> {lang.flag} </button>))} </div> );
};

const ImageUploader = () => {
  const { locale, loadingStates, isBusy, isAuthReady, fileInputRef, handleIdentify } = useAppContext();
  return ( <> <input id="image-upload" type="file" accept="image/*" onChange={(e) => e.target.files && handleIdentify(e.target.files[0])} className="hidden" ref={fileInputRef} /> <button onClick={() => fileInputRef.current.click()} disabled={isBusy || !isAuthReady} className={`w-full py-3 px-6 rounded-xl text-white font-bold text-lg transition-all duration-300 transform ${(!isBusy && isAuthReady) ? 'bg-gradient-to-r from-teal-500 to-blue-600 hover:scale-105 shadow-lg' : 'bg-gray-400 cursor-not-allowed'}`} aria-label={t('uploadButton', locale)}> {loadingStates.identifying ? <EnhancedLoadingSpinner loadingKey="identifying" locale={locale}/> : t('uploadButton', locale)} </button> </> );
};

const EmptyState = () => {
    const { locale, setLoading, setRecognitionResult, setImagePreview } = useAppContext();
    const handleSampleClick = (sample) => {
        setLoading('identifying', true);
        setImagePreview(sample.src);
        setTimeout(() => {
            setRecognitionResult({ name: sample['en-name'], scientificName: sample.scientificName, description: sample['en-desc'] });
            setLoading('identifying', false);
        }, 1000);
    };

    return (
        <div className="text-center mt-8">
            <p className="text-gray-600 mb-4">{t('introText', locale)}</p>
            <h3 className="text-lg font-semibold text-gray-800 mb-4">{t('sampleImagesTitle', locale)}</h3>
            <div className="grid grid-cols-3 gap-4">
                {SAMPLE_IMAGES.map(sample => (
                    <div key={sample.alt} className="cursor-pointer group" onClick={() => handleSampleClick(sample)}>
                        <img src={sample.src} alt={sample.alt} className="rounded-lg shadow-md group-hover:shadow-xl group-hover:scale-105 transition-all duration-300" />
                        <p className="text-sm font-medium text-gray-700 mt-2">{t(sample.alt.toLowerCase(), locale) || sample[`${locale}-name`]}</p>
                    </div>
                ))}
            </div>
        </div>
    );
};

const ResultTabs = () => {
    const { locale, activeTab, setActiveTab, isBusy, moreImages, recognitionResult } = useAppContext();
    if (!recognitionResult || recognitionResult.error) return null;
    
    const tabs = [{id: 'overview', label: t('overviewTab', locale)}, {id: 'moreImages', label: t('moreImagesButton', locale)}, {id: 'funFusion', label: t('funFusionTab', locale)}];

    return (
        <div className="mt-6">
            <div className="border-b border-gray-200">
                <nav className="-mb-px flex space-x-4" aria-label="Tabs">
                    {tabs.map(tab => (
                        <button key={tab.id} onClick={() => setActiveTab(tab.id)} disabled={isBusy} className={`${activeTab === tab.id ? 'border-blue-500 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'} whitespace-nowrap py-3 px-1 border-b-2 font-medium text-sm transition-colors disabled:opacity-50`}>{tab.label}</button>
                    ))}
                </nav>
            </div>
            <div className="py-4">
                {activeTab === 'overview' && <OverviewTab />}
                {activeTab === 'moreImages' && <MoreImagesTab />}
                {activeTab === 'funFusion' && <FunFusionTab />}
            </div>
        </div>
    );
};

const OverviewTab = () => {
    const { locale, loadingStates, recognitionResult, translatedDisplayContent, handleGenerateImages } = useAppContext();
    if (!recognitionResult || recognitionResult.error) return null;

    return (
        <div className="p-4 bg-blue-50 rounded-b-xl">
            {loadingStates.translating ? ( <div className="flex justify-center py-4"><EnhancedLoadingSpinner loadingKey="translating" locale={locale}/></div> ) : 
            (<div className="space-y-3">
                <div><span className="font-semibold text-gray-800">{t('nameLabel', locale)}:</span> <span className="text-gray-700">{translatedDisplayContent.name}</span></div>
                <div><span className="font-semibold text-gray-800">{t('scientificNameLabel', locale)}:</span> <span className="text-gray-700 italic">{recognitionResult.scientificName}</span></div>
                <div><p className="font-semibold text-gray-800 mb-1">{t('descriptionLabel', locale)}:</p><p className="text-gray-700 whitespace-pre-wrap leading-relaxed">{translatedDisplayContent.description}</p></div>
            </div>)
            }
            <button onClick={handleGenerateImages} disabled={useAppContext().isBusy} className={`w-full mt-6 py-2 px-4 rounded-lg text-white font-semibold transition-colors ${!useAppContext().isBusy ? 'bg-purple-500 hover:bg-purple-600' : 'bg-gray-400'}`}>
                {loadingStates.generatingImages ? <EnhancedLoadingSpinner loadingKey="generatingImages" locale={locale}/> : t('moreImagesButton', locale)}
            </button>
        </div>
    );
};

const MoreImagesTab = () => {
    const { moreImages, setModalImage } = useAppContext();
    if(moreImages.length === 0) return <div className="text-center text-gray-500 py-8">No images generated yet. Click the "More Images" button in the Overview tab.</div>;

    return (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {moreImages.map((src, i) => <img key={i} src={src} onClick={() => setModalImage(src)} alt={`Generated marine life ${i+1}`} className="w-full h-full object-cover rounded-lg shadow-md cursor-pointer transition-transform hover:scale-105" />)}
        </div>
    );
};

const FunFusionTab = () => {
    const { locale, isBusy, loadingStates, sceneFileInputRef, synthesisScenePreview, setSynthesisScenePreview, setSynthesisSceneFile, handleSynthesize, synthesisResultImage, setModalImage } = useAppContext();
    
    const handleFileChange = (e) => {
        if(e.target.files && e.target.files[0]) {
            const file = e.target.files[0];
            setSynthesisSceneFile(file);
            setSynthesisScenePreview(URL.createObjectURL(file));
        }
    };

    return (
        <div className="space-y-4 text-center">
            <input type="file" accept="image/*" onChange={handleFileChange} className="hidden" ref={sceneFileInputRef} />
            <button onClick={() => sceneFileInputRef.current.click()} disabled={isBusy} className="w-full py-2 px-4 rounded-lg text-white font-semibold bg-green-500 hover:bg-green-600 disabled:bg-gray-400 transition-colors">{t('uploadSceneButton', locale)}</button>
            {synthesisScenePreview && (
                <div className="p-2 border rounded-lg bg-gray-100 inline-block"><img src={synthesisScenePreview} alt="Scene preview" className="max-w-xs h-auto rounded-md" /></div>
            )}
            <button onClick={handleSynthesize} disabled={isBusy || !synthesisScenePreview} className="w-full py-3 px-6 rounded-xl text-white font-bold bg-gradient-to-r from-cyan-500 to-blue-500 hover:scale-105 transition-transform disabled:bg-gray-400 disabled:transform-none">
                {loadingStates.synthesizing ? <EnhancedLoadingSpinner loadingKey="synthesizing" locale={locale}/> : t('startSynthesisButton', locale)}
            </button>
            {synthesisResultImage && (
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
        if(recognitionResult?.name) {
            setFilename(recognitionResult.name.replace(/\s+/g, '_').toLowerCase());
        }
    }, [recognitionResult]);

    if (!modalImage) return null;
    
    const handleDownload = () => {
        const link = document.createElement('a');
        link.href = modalImage;
        link.download = `${filename || 'image'}.png`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    };

    return (
        <div className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50 p-4" onClick={() => setModalImage(null)} aria-modal="true" role="dialog">
            <div className="bg-white rounded-lg shadow-2xl p-4 max-w-4xl w-full relative" onClick={(e) => e.stopPropagation()}>
                <img src={modalImage} alt="Enlarged view" className="w-full h-auto object-contain rounded-lg max-h-[70vh]" />
                <div className="mt-4 space-y-3 sm:space-y-0 sm:flex sm:flex-row-reverse sm:items-center sm:gap-4">
                     <button onClick={() => setModalImage(null)} className="w-full sm:w-auto py-2 px-6 bg-gray-200 text-gray-800 font-semibold rounded-lg hover:bg-gray-300 transition-colors">{t('closeButton', locale)}</button>
                     <button onClick={handleDownload} className="w-full sm:w-auto py-2 px-6 bg-blue-500 text-white font-semibold rounded-lg hover:bg-blue-600 transition-colors">{t('downloadButton', locale)}</button>
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
// 5. MAIN APP COMPONENT (ASSEMBLER)
// =================================================================
const AppUI = () => {
  const { locale, imagePreview, recognitionResult, errorMessage } = useAppContext();
  const hasResult = recognitionResult && !recognitionResult.error;

  return (
    <div className="min-h-screen bg-gradient-to-br from-teal-50 to-blue-100 flex flex-col items-center p-4 font-sans">
      <div className="bg-white rounded-2xl shadow-xl p-6 sm:p-8 max-w-2xl w-full my-8 border border-blue-200">
        <h1 className="text-4xl font-extrabold text-center text-teal-700 mb-2">{t('appName', locale)}</h1>
        <LanguageSelector />
        <ImageUploader />
        
        {errorMessage && <div className="mt-6 p-4 bg-red-100 border-red-400 text-red-700 rounded-lg text-center">{errorMessage}</div>}
        {recognitionResult?.error && <div className="mt-6 p-4 bg-yellow-100 border-yellow-400 text-yellow-800 rounded-lg text-center">{recognitionResult.error}</div>}
        
        {imagePreview && <div className="mt-6 p-2 border rounded-lg bg-gray-50"><img src={imagePreview} alt="Uploaded preview" className="max-w-full h-auto rounded-lg shadow-md mx-auto" /></div>}
        
        {hasResult ? <ResultTabs /> : <EmptyState />}
        
        <ImageModal />
      </div>
    </div>
  );
};

export default function App() {
  return ( <AppProvider> <AppUI /> </AppProvider> );
}

