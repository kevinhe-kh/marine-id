import React, { useState, useEffect, useRef, createContext, useContext } from 'react';
import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously, signInWithCustomToken, onAuthStateChanged } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

// =================================================================
// 1. CONSTANTS & TRANSLATIONS
// =================================================================
const translations = {
  'zh': { appName: '海洋生物识别器', uploadButton: '上传照片并识别', identifying: '识别中...', moreImagesButton: '更多图片', generatingImages: '正在生成图片...', noImageSelected: '没有选择图片。', apiError: 'API请求失败', recognitionFailed: '识别失败', noMarineLife: '未能识别出海洋生物。请尝试上传更清晰的图片。', errorDuringRecognition: '识别过程中发生错误', nameLabel: '名称', scientificNameLabel: '学名', errorAuthFailed: '认证失败，请刷新页面重试。', errorFirebaseInit: 'Firebase初始化失败。', languageName: '中文', translatingContent: '正在翻译内容...', relatedSpeciesButton: '相关生物', suggestingSpecies: '正在建议相关生物...', relatedSpeciesTitle: '相关生物', noRelatedSpecies: '未能找到相关生物。', errorSuggestingSpecies: '建议相关生物时发生错误：' },
  'en': { appName: 'Marine Life Identifier', uploadButton: 'Upload Photo & Identify', identifying: 'Identifying...', moreImagesButton: 'More Images', generatingImages: 'Generating images...', noImageSelected: 'No image selected.', apiError: 'API request failed', recognitionFailed: 'Recognition failed', noMarineLife: 'Could not identify marine life. Please try a clearer image.', errorDuringRecognition: 'Error during recognition', nameLabel: 'Name', scientificNameLabel: 'Scientific Name', errorAuthFailed: 'Authentication failed, please refresh the page.', errorFirebaseInit: 'Firebase initialization failed.', languageName: 'English', translatingContent: 'Translating content...', relatedSpeciesButton: 'Related Species', suggestingSpecies: 'Suggesting related species...', relatedSpeciesTitle: 'Related Species', noRelatedSpecies: 'Could not find related species.', errorSuggestingSpecies: 'Error suggesting related species:' },
  'ja': { appName: '海洋生物識別ツール', uploadButton: '写真をアップロードして識別', identifying: '識別中...', moreImagesButton: 'その他の画像', generatingImages: '画像を生成中...', noImageSelected: '画像が選択されていません。', apiError: 'APIリクエストに失敗しました', recognitionFailed: '識別に失敗しました', noMarineLife: '海洋生物を識別できませんでした。より鮮明な画像を試してください。', errorDuringRecognition: '識別中にエラーが発生しました', nameLabel: '名称', scientificNameLabel: '学名', errorAuthFailed: '認証に失敗しました。ページを再読み込みしてください。', errorFirebaseInit: 'Firebaseの初期化に失敗しました。', languageName: '日本語', translatingContent: 'コンテンツを翻訳中...', relatedSpeciesButton: '関連生物', suggestingSpecies: '関連生物を提案中...', relatedSpeciesTitle: '関連生物', noRelatedSpecies: '関連生物は見つかりませんでした。', errorSuggestingSpecies: '関連生物の提案中にエラーが発生しました：' },
  'de': { appName: 'Meereslebewesen-Identifikator', uploadButton: 'Foto hochladen & identifizieren', identifying: 'Identifiziere...', moreImagesButton: 'Weitere Bilder', generatingImages: 'Bilder werden generiert...', noImageSelected: 'Kein Bild ausgewählt.', apiError: 'API-Anfrage fehlgeschlagen', recognitionFailed: 'Erkennung fehlgeschlagen', noMarineLife: 'Meereslebewesen konnte nicht identifiziert werden. Bitte versuchen Sie ein klareres Bild.', errorDuringRecognition: 'Fehler während der Erkennung', nameLabel: 'Name', scientificNameLabel: 'Wissenschaftlicher Name', errorAuthFailed: 'Authentifizierung fehlgeschlagen, bitte aktualisieren Sie die Seite.', errorFirebaseInit: 'Firebase-Initialisierung fehlgeschlagen.', languageName: 'Deutsch', translatingContent: 'Inhalt wird übersetzt...', relatedSpeciesButton: 'Verwandte Arten', suggestingSpecies: 'Verwandte Arten vorschlagen...', relatedSpeciesTitle: 'Verwandte Arten', noRelatedSpecies: 'Es konnten keine verwandten Arten gefunden werden.', errorSuggestingSpecies: 'Fehler beim Vorschlagen verwandter Arten:' },
  'es': { appName: 'Identificador de Vida Marina', uploadButton: 'Subir Foto e Identificar', identifying: 'Identificando...', moreImagesButton: 'Más imágenes', generatingImages: 'Generando imágenes...', noImageSelected: 'No se ha seleccionado ninguna imagen.', apiError: 'La solicitud de API falló', recognitionFailed: 'Fallo de reconocimiento', noMarineLife: 'No se pudo identificar vida marina. Por favor, intente una imagen más clara.', errorDuringRecognition: 'Error durante el reconocimiento', nameLabel: 'Nombre', scientificNameLabel: 'Nombre Científico', errorAuthFailed: 'Autenticación fallida, por favor actualice la página.', errorFirebaseInit: 'Fallo al inicializar Firebase.', languageName: 'Español', translatingContent: 'Traduciendo contenido...', relatedSpeciesButton: 'Especies Relacionadas', suggestingSpecies: 'Sugiriendo especies relacionadas...', relatedSpeciesTitle: 'Especies Relacionadas', noRelatedSpecies: 'No se pudieron encontrar especies relacionadas.', errorSuggestingSpecies: 'Error al sugerir especies relacionadas:' },
  'ko': { appName: '해양 생물 식별기', uploadButton: '사진 업로드 및 식별', identifying: '식별 중...', moreImagesButton: '더 많은 이미지', generatingImages: '이미지 생성 중...', noImageSelected: '선택된 이미지가 없습니다.', apiError: 'API 요청 실패', recognitionFailed: '식별 실패', noMarineLife: '해양 생물을 식별할 수 없습니다. 더 선명한 이미지를 시도하십시오.', errorDuringRecognition: '식별 중 오류 발생', nameLabel: '이름', scientificNameLabel: '학명', errorAuthFailed: '인증 실패, 페이지를 새로 고치십시오.', errorFirebaseInit: 'Firebase 초기화 실패.', languageName: '한국어', translatingContent: '콘텐츠 번역 중...', relatedSpeciesButton: '관련 종', suggestingSpecies: '관련 종 제안 중...', relatedSpeciesTitle: '관련 종', noRelatedSpecies: '관련 종을 찾을 수 없습니다.', errorSuggestingSpecies: '관련 종 제안 중 오류 발생:' },
  'ru': { appName: 'Идентификатор морской жизни', uploadButton: 'Загрузить фото и идентифицировать', identifying: 'Идентификация...', moreImagesButton: 'Больше изображений', generatingImages: 'Генерация изображений...', noImageSelected: 'Изображение не выбрано.', apiError: 'Сбой запроса API', recognitionFailed: 'Ошибка распознавания', noMarineLife: 'Не удалось определить морскую жизнь. Пожалуйста, попробуйте более четкое изображение.', errorDuringRecognition: 'Ошибка во время распознавания', nameLabel: 'Имя', scientificNameLabel: 'Научное название', errorAuthFailed: 'Ошибка аутентификации, пожалуйста, обновите страницу.', errorFirebaseInit: 'Ошибка инициализации Firebase.', languageName: 'Русский', translatingContent: 'Перевод содержимого...', relatedSpeciesButton: 'Связанные виды', suggestingSpecies: 'Предложение связанных видов...', relatedSpeciesTitle: 'Связанные виды', noRelatedSpecies: 'Связанные виды не найдены.', errorSuggestingSpecies: 'Ошибка при предложении связанных видов:' }
};
const t = (key, locale) => translations[locale]?.[key] || key;

// =================================================================
// 2. API SERVICE LAYER
// =================================================================
const apiService = {
  async fetchFromGemini(payload) {
    const apiKey = ""; // Provided by Canvas
    const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`;
    const response = await fetch(apiUrl, {
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

  async identifyImage(base64ImageData, fileType, locale) {
    const promptText = `Identify the marine life in this image. Provide its name, scientific name, and a brief description.
- The name should be in ${t('languageName', locale)}.
- The scientific name should be in English.
- The description should be in ${t('languageName', locale)}.
Return the result in JSON format, containing 'name', 'scientificName', and 'description'.
If there's no obvious marine life, return a JSON object like { "error": "${t('noMarineLife', locale)}" }.`;

    const payload = {
      contents: [{ role: "user", parts: [{ text: promptText }, { inlineData: { mimeType: fileType, data: base64ImageData } }] }],
      generationConfig: { responseMimeType: "application/json", responseSchema: { type: "OBJECT", properties: { "name": { "type": "STRING" }, "scientificName": { "type": "STRING" }, "description": { "type": "STRING" } } } }
    };
    const result = await this.fetchFromGemini(payload);
    return JSON.parse(result.candidates[0].content.parts[0].text);
  },

  async translateText(text, targetLocale) {
    if (!text || !targetLocale) return text;
    const translationPrompt = `Translate the following text into ${t('languageName', targetLocale)}. Provide only the translated text, without any introductory phrases. Original text: "${text}"`;
    const payload = { contents: [{ role: "user", parts: [{ text: translationPrompt }] }] };
    const result = await this.fetchFromGemini(payload);
    return result.candidates[0].content.parts[0].text.trim();
  },

  async generateImages(prompt) {
    const payload = { instances: { prompt }, parameters: { "sampleCount": 4 } };
    const apiKey = ""; // Provided by Canvas
    const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-002:predict?key=${apiKey}`;
    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    if (!response.ok) {
        const errorData = await response.json();
        throw new Error(`API Error: ${response.status} - ${errorData.message || response.statusText}`);
    }
    const result = await response.json();
    return result.predictions?.map(pred => `data:image/png;base64,${pred.bytesBase64Encoded}`) || [];
  },

  async suggestRelatedSpecies(queryName, scientificName, locale) {
    const prompt = `Based on "${queryName}" (scientific name: ${scientificName}), suggest 3 to 5 related marine life species. Provide only a JSON array of strings, where each string is the name of a related species. The names should be in ${t('languageName', locale)}. Example: ["Species A", "Species B"].`;
    const payload = {
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: { responseMimeType: "application/json", responseSchema: { type: "ARRAY", items: { type: "STRING" } } }
    };
    const result = await this.fetchFromGemini(payload);
    return JSON.parse(result.candidates[0].content.parts[0].text);
  }
};

// =================================================================
// 3. CONTEXT FOR STATE MANAGEMENT
// =================================================================
const AppContext = createContext();

const AppProvider = ({ children }) => {
  const [locale, setLocale] = useState('zh');
  const [loadingStates, setLoadingStates] = useState({ identifying: false, translating: false, generatingImages: false, suggestingSpecies: false });
  const [recognitionResult, setRecognitionResult] = useState(null);
  const [translatedDisplayContent, setTranslatedDisplayContent] = useState({ name: '', description: '' });
  const [moreImages, setMoreImages] = useState([]);
  const [relatedSpecies, setRelatedSpecies] = useState([]);
  const [imagePreview, setImagePreview] = useState(null);
  const [errorMessage, setErrorMessage] = useState('');
  const [isAuthReady, setIsAuthReady] = useState(false);

  const fileInputRef = useRef(null);

  // Helper to manage loading states
  const setLoading = (key, value) => setLoadingStates(prev => ({ ...prev, [key]: value }));
  const isBusy = Object.values(loadingStates).some(Boolean);

  // Firebase initialization
  useEffect(() => {
    try {
      const firebaseConfig = typeof __firebase_config !== 'undefined' ? JSON.parse(__firebase_config) : {};
      const app = initializeApp(firebaseConfig);
      const auth = getAuth(app);
      const unsubscribe = onAuthStateChanged(auth, async (user) => {
        if (!user) {
          try {
            const token = typeof __initial_auth_token !== 'undefined' ? __initial_auth_token : null;
            await (token ? signInWithCustomToken(auth, token) : signInAnonymously(auth));
          } catch (error) { setErrorMessage(t('errorAuthFailed', locale)); }
        }
        setIsAuthReady(true);
      });
      return () => unsubscribe();
    } catch (error) { setErrorMessage(t('errorFirebaseInit', locale)); }
  }, [locale]);

  // Translate content when locale or result changes
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
      } catch (error) {
        setErrorMessage(error.message);
        setTranslatedDisplayContent({ name: recognitionResult.name, description: recognitionResult.description });
      } finally {
        setLoading('translating', false);
      }
    };
    translate();
  }, [locale, recognitionResult]);
  
  const resetState = () => {
      setRecognitionResult(null);
      setErrorMessage('');
      setMoreImages([]);
      setTranslatedDisplayContent({ name: '', description: '' });
      setRelatedSpecies([]);
      setImagePreview(null);
  };

  const imageToBase64 = (file) => new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => resolve(reader.result.split(',')[1]);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });

  const handleIdentify = async (file) => {
    resetState();
    if (!file) {
      setErrorMessage(t('noImageSelected', locale));
      return;
    }
    setLoading('identifying', true);
    setImagePreview(URL.createObjectURL(file));

    try {
      const base64ImageData = await imageToBase64(file);
      const result = await apiService.identifyImage(base64ImageData, file.type, locale);
      setRecognitionResult(result);
      if (result.error) setErrorMessage(result.error);
    } catch (error) {
      setErrorMessage(`${t('errorDuringRecognition', locale)}: ${error.message}`);
      setRecognitionResult(null);
    } finally {
      setLoading('identifying', false);
    }
  };
  
  const handleGenerateImages = async () => {
      if (!recognitionResult || recognitionResult.error) return;
      setLoading('generatingImages', true);
      try {
          const images = await apiService.generateImages(translatedDisplayContent.name || recognitionResult.name);
          setMoreImages(images);
      } catch (error) {
          setErrorMessage(error.message);
      } finally {
          setLoading('generatingImages', false);
      }
  };

  const handleSuggestSpecies = async () => {
      if (!recognitionResult || recognitionResult.error) return;
      setLoading('suggestingSpecies', true);
      try {
          const species = await apiService.suggestRelatedSpecies(translatedDisplayContent.name || recognitionResult.name, recognitionResult.scientificName, locale);
          setRelatedSpecies(species);
      } catch (error) {
          setErrorMessage(error.message);
      } finally {
          setLoading('suggestingSpecies', false);
      }
  };

  const value = {
    locale, setLocale,
    loadingStates, isBusy,
    recognitionResult, translatedDisplayContent,
    moreImages, relatedSpecies,
    imagePreview, errorMessage,
    isAuthReady,
    fileInputRef,
    handleIdentify,
    handleGenerateImages,
    handleSuggestSpecies
  };

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
};

// Custom hook to use the context
const useAppContext = () => useContext(AppContext);

// =================================================================
// 4. CHILD COMPONENTS
// =================================================================

const LoadingSpinner = ({ text }) => (
  <span className="flex items-center justify-center">
    <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle><path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
    {text}
  </span>
);

const LanguageSelector = () => {
  const { locale, setLocale } = useAppContext();
  const languages = [{ code: 'zh', flag: '🇨🇳' }, { code: 'en', flag: '🇺🇸' }, { code: 'ja', flag: '🇯🇵' }, { code: 'de', flag: '🇩🇪' }, { code: 'es', flag: '🇪🇸' }, { code: 'ko', flag: '🇰🇷' }, { code: 'ru', flag: '🇷🇺' }];
  
  return (
    <div className="flex flex-wrap justify-center gap-2 sm:gap-3 mb-8">
      {languages.map((lang) => (
        <button key={lang.code} onClick={() => setLocale(lang.code)} className={`p-1.5 rounded-full text-2xl transition-transform transform hover:scale-110 ${locale === lang.code ? 'ring-2 ring-blue-500' : ''}`} title={t('languageName', lang.code)}>
          {lang.flag}
        </button>
      ))}
    </div>
  );
};

const ImageUploader = () => {
  const { locale, loadingStates, isBusy, isAuthReady, fileInputRef, handleIdentify } = useAppContext();
  
  const handleFileSelected = (event) => {
    if (event.target.files && event.target.files[0]) {
      handleIdentify(event.target.files[0]);
    }
  };

  return (
    <>
      <input id="image-upload" type="file" accept="image/*" onChange={handleFileSelected} className="hidden" ref={fileInputRef} />
      <button onClick={() => fileInputRef.current.click()} disabled={isBusy || !isAuthReady} className={`w-full py-3 px-6 rounded-xl text-white font-bold text-lg transition-all duration-300 transform ${(!isBusy && isAuthReady) ? 'bg-gradient-to-r from-teal-500 to-blue-600 hover:scale-105 shadow-lg' : 'bg-gray-400 cursor-not-allowed'}`}>
        {loadingStates.identifying ? <LoadingSpinner text={t('identifying', locale)} /> : t('uploadButton', locale)}
      </button>
    </>
  );
};

const ResultDisplay = () => {
    const { locale, loadingStates, recognitionResult, translatedDisplayContent } = useAppContext();
    if (!recognitionResult || recognitionResult.error) return null;

    return (
        <div className="mt-6 p-6 bg-blue-50 rounded-xl border border-blue-200 shadow-md">
            {loadingStates.translating ? (
                <div className="flex justify-center py-4"><LoadingSpinner text={t('translatingContent', locale)} /></div>
            ) : (
                <p className="text-gray-800 leading-relaxed whitespace-pre-wrap">
                    <span className="font-semibold">{t('nameLabel', locale)}:</span> {translatedDisplayContent.name}<br/>
                    <span className="font-semibold">{t('scientificNameLabel', locale)}:</span> {recognitionResult.scientificName}<br/><br/>
                    {translatedDisplayContent.description}
                </p>
            )}
            <ActionButtons />
        </div>
    );
};

const ActionButtons = () => {
    const { locale, isBusy, loadingStates, handleGenerateImages, handleSuggestSpecies } = useAppContext();
    return (
        <div className="flex flex-col sm:flex-row gap-4 mt-6">
            <button onClick={handleGenerateImages} disabled={isBusy} className={`flex-1 py-3 px-6 rounded-xl text-white font-bold text-lg transition-all duration-300 transform ${!isBusy ? 'bg-gradient-to-r from-purple-500 to-pink-600 hover:scale-105 shadow-lg' : 'bg-gray-400 cursor-not-allowed'}`}>
                {loadingStates.generatingImages ? <LoadingSpinner text={t('generatingImages', locale)} /> : t('moreImagesButton', locale)}
            </button>
            <button onClick={handleSuggestSpecies} disabled={isBusy} className={`flex-1 py-3 px-6 rounded-xl text-white font-bold text-lg transition-all duration-300 transform ${!isBusy ? 'bg-gradient-to-r from-green-500 to-blue-700 hover:scale-105 shadow-lg' : 'bg-gray-400 cursor-not-allowed'}`}>
                {loadingStates.suggestingSpecies ? <LoadingSpinner text={t('suggestingSpecies', locale)} /> : t('relatedSpeciesButton', locale)}
            </button>
        </div>
    );
};

const ImageGrid = () => {
    const { moreImages } = useAppContext();
    if (moreImages.length === 0) return null;
    return (
        <div className="mt-6 grid grid-cols-2 md:grid-cols-4 gap-4 p-4 bg-gray-50 rounded-xl shadow-inner">
            {moreImages.map((imgSrc, index) => (
              <div key={index} className="rounded-lg overflow-hidden shadow-md">
                <img src={imgSrc} alt={`Generated image ${index + 1}`} className="w-full h-full object-cover transition-transform duration-300 hover:scale-105" />
              </div>
            ))}
        </div>
    );
};

const RelatedSpeciesList = () => {
    const { locale, relatedSpecies } = useAppContext();
    if (relatedSpecies.length === 0) return null;
    return (
        <div className="mt-6 p-6 bg-green-50 rounded-xl border border-green-200 shadow-md">
            <h2 className="text-2xl font-semibold text-green-700 mb-4">{t('relatedSpeciesTitle', locale)}:</h2>
            <ul className="list-disc list-inside text-gray-800 space-y-2">
                {relatedSpecies.map((species, index) => <li key={index} className="text-lg">{species}</li>)}
            </ul>
        </div>
    );
};

const Messages = () => {
    const { errorMessage, recognitionResult } = useAppContext();
    const llmError = recognitionResult?.error;
    
    if (errorMessage) {
        return <div className="mt-6 p-4 bg-red-100 border-red-400 text-red-700 rounded-lg text-center">{errorMessage}</div>
    }
    if(llmError) {
        return <div className="mt-6 p-4 bg-red-100 border border-red-400 text-red-700 rounded-lg text-center">{llmError}</div>
    }
    return null;
}


// =================================================================
// 5. MAIN APP COMPONENT (ASSEMBLER)
// =================================================================
const AppUI = () => {
  const { locale, imagePreview } = useAppContext();

  return (
    <div className="min-h-screen bg-gradient-to-br from-teal-50 to-blue-100 flex flex-col items-center justify-center p-4 font-inter">
      <div className="bg-white rounded-2xl shadow-xl p-8 max-w-2xl w-full my-8 border border-blue-200">
        <h1 className="text-4xl font-extrabold text-center text-teal-700 mb-6">{t('appName', locale)}</h1>
        <LanguageSelector />
        <ImageUploader />
        {imagePreview && (
          <div className="mt-6 p-4 border border-gray-200 rounded-lg bg-gray-50">
            <img src={imagePreview} alt="Selected preview" className="max-w-full h-auto rounded-lg shadow-md mx-auto" />
          </div>
        )}
        <Messages />
        <ResultDisplay />
        <ImageGrid />
        <RelatedSpeciesList />
      </div>
    </div>
  );
};

// The final export wraps the UI with the provider
export default function App() {
  return (
    <AppProvider>
      <AppUI />
    </AppProvider>
  );
}

//(A) 技术架构与代码质量 (Technical Architecture & Code Quality)
 * 组件化重构 (Componentization)
   * 问题：目前所有逻辑都在 App.js 中，这个文件已经非常庞大。随着功能增加，它会变得越来越难以维护。
   * 建议：将UI拆分为更小的、可复用的组件。例如：
     * LanguageSelector.js：专门负责语言切换的按钮组。
     * ImageUploader.js：处理图片上传、预览和主识别按钮。
     * ResultDisplay.js：展示识别结果（名称、学名、描述）。
     * ActionButtons.js：包含“更多图片”和“相关生物”的按钮。
     * ImageGrid.js：展示生成的“更多图片”。
   * 优势：代码更清晰、更易于管理和测试。每个组件只关心自己的事（单一职责原则）。
 * API服务层抽象 (API Service Abstraction)
   * 问题：API的 fetch 调用逻辑直接写在组件的函数中。
   * 建议：创建一个专门的API服务模块，例如 services/geminiService.js。
     // services/geminiService.js
export const identifyImage = async (base64ImageData, fileType, locale) => { ... };
export const generateImages = async (prompt) => { ... };
export const translateText = async (text, targetLocale) => { ... };

   * 优势：将API通信逻辑与UI组件分离。未来如果更换API或修改请求格式，只需修改服务文件，而无需触碰任何UI组件。这也使得代码更加整洁。
 * 更优雅的状态管理 (Advanced State Management)
   * 问题：当应用变得复杂时，通过Props在多层组件之间传递状态和函数（Prop Drilling）会变得很麻烦。
   * 建议：引入React Context API。您可以创建一个 AppContext，用来全局提供如 locale, isBusy, recognitionResult 等状态，以及 identifyMarineLife 等核心函数。
   * 优势：任何深层嵌套的组件都可以直接访问需要的状态或函数，而无需父组件层层传递，极大地简化了组件间的通信。
"重构一下代码，功能不要受影响，我们下一步再说

//// =================================================================
// Component: LanguageSelector - 只负责语言切换
// =================================================================
const LanguageSelector = ({ currentLocale, onSelectLocale }) => {
  // ... 语言切换按钮的 JSX 和逻辑 ...
};

// =================================================================
// Component: ResultDisplay - 只负责显示识别结果
// =================================================================
const ResultDisplay = ({ result, translatedContent, isTranslating }) => {
  // ... 显示名称、学名、描述的 JSX 和逻辑 ...
};

// =================================================================
// Main App Component - 负责组装所有子组件和管理主状态
// =================================================================
export default function App() {
  // ... 所有的 useState, useEffect 和核心函数 ...

  return (
    <div>
      <h1>{t('appName', locale)}</h1>
      
      {/* 使用子组件 */}
      <LanguageSelector currentLocale={locale} onSelectLocale={setLocale} />
      
      {/* ... 其他上传逻辑 ... */}
      
      {/* 使用子组件 */}
      <ResultDisplay 
        result={recognitionResult} 
        translatedContent={translatedDisplayContent}
        isTranslating={translatingContent}
      />
      
      {/* ... 其他组件 ... */}
    </div>
  );
}
