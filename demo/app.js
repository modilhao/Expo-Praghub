/**
 * Sistema de Pre-commit Enterprise - Demo JavaScript
 * Demonstra funcionalidades avançadas e boas práticas
 */

// Configuração global
const CONFIG = {
  api: {
    baseUrl: 'https://api.example.com',
    timeout: 5000,
    retries: 3
  },
  ui: {
    animationDuration: 300,
    debounceDelay: 250
  },
  cache: {
    ttl: 300000, // 5 minutos
    maxSize: 100
  }
};

// Utilitários
class Utils {
  static debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  }

  static throttle(func, limit) {
    let inThrottle;
    return function() {
      const args = arguments;
      const context = this;
      if (!inThrottle) {
        func.apply(context, args);
        inThrottle = true;
        setTimeout(() => inThrottle = false, limit);
      }
    };
  }

  static formatBytes(bytes, decimals = 2) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
  }

  static generateId() {
    return Math.random().toString(36).substr(2, 9);
  }
}

// Sistema de Cache
class CacheManager {
  constructor(maxSize = CONFIG.cache.maxSize) {
    this.cache = new Map();
    this.maxSize = maxSize;
  }

  set(key, value, ttl = CONFIG.cache.ttl) {
    if (this.cache.size >= this.maxSize) {
      const firstKey = this.cache.keys().next().value;
      this.cache.delete(firstKey);
    }

    const expiresAt = Date.now() + ttl;
    this.cache.set(key, { value, expiresAt });
  }

  get(key) {
    const item = this.cache.get(key);
    if (!item) return null;

    if (Date.now() > item.expiresAt) {
      this.cache.delete(key);
      return null;
    }

    return item.value;
  }

  clear() {
    this.cache.clear();
  }

  size() {
    return this.cache.size;
  }
}

// API Client
class ApiClient {
  constructor(baseUrl = CONFIG.api.baseUrl) {
    this.baseUrl = baseUrl;
    this.cache = new CacheManager();
  }

  async request(endpoint, options = {}) {
    const url = `${this.baseUrl}${endpoint}`;
    const cacheKey = `${options.method || 'GET'}_${url}`;

    // Verificar cache para GET requests
    if (!options.method || options.method === 'GET') {
      const cached = this.cache.get(cacheKey);
      if (cached) return cached;
    }

    const config = {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        ...options.headers
      },
      ...options
    };

    try {
      const response = await fetch(url, config);
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json();
      
      // Cache apenas GET requests bem-sucedidas
      if (config.method === 'GET') {
        this.cache.set(cacheKey, data);
      }

      return data;
    } catch (error) {
      console.error('API Request failed:', error);
      throw error;
    }
  }

  get(endpoint, options = {}) {
    return this.request(endpoint, { ...options, method: 'GET' });
  }

  post(endpoint, data, options = {}) {
    return this.request(endpoint, {
      ...options,
      method: 'POST',
      body: JSON.stringify(data)
    });
  }

  put(endpoint, data, options = {}) {
    return this.request(endpoint, {
      ...options,
      method: 'PUT',
      body: JSON.stringify(data)
    });
  }

  delete(endpoint, options = {}) {
    return this.request(endpoint, { ...options, method: 'DELETE' });
  }
}

// Gerenciador de Estado
class StateManager {
  constructor(initialState = {}) {
    this.state = { ...initialState };
    this.listeners = new Map();
  }

  getState() {
    return { ...this.state };
  }

  setState(updates) {
    const prevState = { ...this.state };
    this.state = { ...this.state, ...updates };
    
    // Notificar listeners
    this.listeners.forEach((callback, key) => {
      callback(this.state, prevState);
    });
  }

  subscribe(key, callback) {
    this.listeners.set(key, callback);
    
    // Retornar função de unsubscribe
    return () => {
      this.listeners.delete(key);
    };
  }
}

// Componente de UI
class UIComponent {
  constructor(element, options = {}) {
    this.element = typeof element === 'string' ? document.querySelector(element) : element;
    this.options = { ...options };
    this.state = new StateManager();
    this.init();
  }

  init() {
    this.bindEvents();
    this.render();
  }

  bindEvents() {
    // Override em subclasses
  }

  render() {
    // Override em subclasses
  }

  destroy() {
    if (this.element) {
      this.element.innerHTML = '';
      this.element = null;
    }
  }
}

// Componente de Notificação
class NotificationManager extends UIComponent {
  constructor() {
    super(document.body);
    this.notifications = [];
    this.createContainer();
  }

  createContainer() {
    this.container = document.createElement('div');
    this.container.className = 'notification-container';
    this.container.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      z-index: 10000;
      pointer-events: none;
    `;
    document.body.appendChild(this.container);
  }

  show(message, type = 'info', duration = 5000) {
    const id = Utils.generateId();
    const notification = this.createNotification(id, message, type);
    
    this.notifications.push({ id, element: notification, type });
    this.container.appendChild(notification);

    // Auto-remove
    setTimeout(() => {
      this.remove(id);
    }, duration);

    return id;
  }

  createNotification(id, message, type) {
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.dataset.id = id;
    notification.style.cssText = `
      background: ${this.getTypeColor(type)};
      color: white;
      padding: 12px 20px;
      border-radius: 8px;
      margin-bottom: 10px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
      pointer-events: auto;
      cursor: pointer;
      transform: translateX(100%);
      transition: transform 0.3s ease;
      max-width: 400px;
      word-wrap: break-word;
    `;
    notification.textContent = message;

    // Animação de entrada
    setTimeout(() => {
      notification.style.transform = 'translateX(0)';
    }, 10);

    // Click para remover
    notification.addEventListener('click', () => {
      this.remove(id);
    });

    return notification;
  }

  getTypeColor(type) {
    const colors = {
      success: '#10b981',
      error: '#ef4444',
      warning: '#f59e0b',
      info: '#3b82f6'
    };
    return colors[type] || colors.info;
  }

  remove(id) {
    const notification = this.container.querySelector(`[data-id="${id}"]`);
    if (notification) {
      notification.style.transform = 'translateX(100%)';
      setTimeout(() => {
        if (notification.parentNode) {
          notification.parentNode.removeChild(notification);
        }
        this.notifications = this.notifications.filter(n => n.id !== id);
      }, 300);
    }
  }

  clear() {
    this.notifications.forEach(n => this.remove(n.id));
  }
}

// Aplicação Principal
class PreCommitDemo {
  constructor() {
    this.api = new ApiClient();
    this.notifications = new NotificationManager();
    this.state = new StateManager({
      isLoading: false,
      files: [],
      results: []
    });
    
    this.init();
  }

  init() {
    this.bindEvents();
    this.loadInitialData();
    this.notifications.show('Sistema de Pre-commit Enterprise inicializado!', 'success');
  }

  bindEvents() {
    // Simular verificação de arquivos
    const checkButton = document.getElementById('check-files');
    if (checkButton) {
      checkButton.addEventListener('click', Utils.debounce(() => {
        this.runPreCommitCheck();
      }, CONFIG.ui.debounceDelay));
    }

    // Scroll suave para seções
    document.querySelectorAll('a[href^="#"]').forEach(link => {
      link.addEventListener('click', (e) => {
        e.preventDefault();
        const target = document.querySelector(link.getAttribute('href'));
        if (target) {
          target.scrollIntoView({ behavior: 'smooth' });
        }
      });
    });
  }

  async loadInitialData() {
    this.state.setState({ isLoading: true });
    
    try {
      // Simular carregamento de dados
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      const mockFiles = [
        { name: 'index.html', type: 'html', size: 2048 },
        { name: 'styles.css', type: 'css', size: 4096 },
        { name: 'app.js', type: 'javascript', size: 8192 }
      ];
      
      this.state.setState({ 
        files: mockFiles,
        isLoading: false 
      });
      
    } catch (error) {
      this.notifications.show('Erro ao carregar dados iniciais', 'error');
      this.state.setState({ isLoading: false });
    }
  }

  async runPreCommitCheck() {
    this.notifications.show('Executando verificações de pre-commit...', 'info');
    this.state.setState({ isLoading: true });

    try {
      // Simular verificação
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      const results = this.state.getState().files.map(file => ({
        file: file.name,
        status: Math.random() > 0.3 ? 'success' : 'warning',
        score: Math.floor(Math.random() * 30) + 70,
        issues: Math.random() > 0.5 ? [] : ['Otimização sugerida']
      }));
      
      this.state.setState({ 
        results,
        isLoading: false 
      });
      
      const hasErrors = results.some(r => r.status === 'error');
      const message = hasErrors ? 
        'Verificação concluída com erros!' : 
        'Verificação concluída com sucesso!';
      
      this.notifications.show(message, hasErrors ? 'error' : 'success');
      
    } catch (error) {
      this.notifications.show('Erro durante verificação', 'error');
      this.state.setState({ isLoading: false });
    }
  }
}

// Performance Monitor
class PerformanceMonitor {
  constructor() {
    this.metrics = new Map();
    this.observers = [];
    this.init();
  }

  init() {
    // Web Vitals
    this.observeWebVitals();
    
    // Resource timing
    this.observeResourceTiming();
    
    // Navigation timing
    this.observeNavigationTiming();
  }

  observeWebVitals() {
    // Simular observação de Web Vitals
    if ('PerformanceObserver' in window) {
      const observer = new PerformanceObserver((list) => {
        list.getEntries().forEach((entry) => {
          this.recordMetric(entry.name, entry.value);
        });
      });
      
      try {
        observer.observe({ entryTypes: ['measure', 'navigation'] });
        this.observers.push(observer);
      } catch (e) {
        console.warn('Performance Observer não suportado:', e);
      }
    }
  }

  observeResourceTiming() {
    if ('performance' in window && 'getEntriesByType' in performance) {
      const resources = performance.getEntriesByType('resource');
      resources.forEach(resource => {
        this.recordMetric(`resource_${resource.name}`, resource.duration);
      });
    }
  }

  observeNavigationTiming() {
    if ('performance' in window && 'timing' in performance) {
      const timing = performance.timing;
      const loadTime = timing.loadEventEnd - timing.navigationStart;
      this.recordMetric('page_load_time', loadTime);
    }
  }

  recordMetric(name, value) {
    this.metrics.set(name, {
      value,
      timestamp: Date.now()
    });
  }

  getMetrics() {
    return Object.fromEntries(this.metrics);
  }

  destroy() {
    this.observers.forEach(observer => observer.disconnect());
    this.observers = [];
    this.metrics.clear();
  }
}

// Inicialização quando DOM estiver pronto
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeApp);
} else {
  initializeApp();
}

function initializeApp() {
  // Inicializar aplicação
  window.preCommitDemo = new PreCommitDemo();
  window.performanceMonitor = new PerformanceMonitor();
  
  // Logs de desenvolvimento
  if (process?.env?.NODE_ENV === 'development') {
    console.log('🚀 Pre-commit Demo inicializado');
    console.log('📊 Performance Monitor ativo');
  }
}

// Cleanup ao sair da página
window.addEventListener('beforeunload', () => {
  if (window.performanceMonitor) {
    window.performanceMonitor.destroy();
  }
});

// Export para módulos
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    Utils,
    CacheManager,
    ApiClient,
    StateManager,
    UIComponent,
    NotificationManager,
    PreCommitDemo,
    PerformanceMonitor
  };
}