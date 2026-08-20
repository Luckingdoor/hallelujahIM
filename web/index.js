var app = new Vue({
  el: "#app",
  data: {
    loading: false,
    subLoading: false,
    newKey: "",
    newValue: "",
    preference: {
      showTranslation: true,
      commitWordWithSpace: true,
      enableNextWordPrediction: false
    },
    substitutions: {},
    importFrequency: 300000,
    importLoading: false,
    importResult: null,
    importError: "",
    dictSources: null
  },
  methods: {
    getPreference() {
      fetch("http://localhost:62718/preference")
        .then(function(res) {
          return res.json();
        })
        .then(preference => {
          this.preference = preference;
        });
    },
    updatePreference() {
      this.loading = true;
      fetch("http://localhost:62718/preference", {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json"
        },
        body: JSON.stringify(this.preference)
      })
        .then(function(res) {
          return res.json();
        })
        .then(preference => {
          this.loading = false;
        });
    },
    loadSubstitutions() {
      fetch("http://localhost:62718/substitutions")
        .then(function(res) {
          return res.json();
        })
        .then(data => {
          this.substitutions = data;
        });
    },
    addSubstitution() {
      if (!this.newKey || !this.newValue) return;
      this.subLoading = true;
      fetch("http://localhost:62718/substitutions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ key: this.newKey, value: this.newValue })
      })
        .then(function(res) {
          return res.json();
        })
        .then(data => {
          this.substitutions = data;
          this.newKey = "";
          this.newValue = "";
          this.subLoading = false;
        });
    },
    removeSubstitution(key) {
      this.subLoading = true;
      fetch("http://localhost:62718/substitutions/" + encodeURIComponent(key), {
        method: "DELETE"
      })
        .then(function(res) {
          return res.json();
        })
        .then(data => {
          this.substitutions = data;
          this.subLoading = false;
        });
    },
    loadDictSources() {
      fetch("http://localhost:62718/dictionary/sources")
        .then(function(res) {
          return res.json();
        })
        .then(data => {
          this.dictSources = data;
        });
    },
    importDictionary() {
      var input = this.$refs.dictFile;
      if (!input.files || !input.files.length) {
        return;
      }
      this.importLoading = true;
      this.importResult = null;
      this.importError = "";

      var form = new FormData();
      form.append("file", input.files[0]);
      form.append("frequency", String(this.importFrequency || 300000));

      fetch("http://localhost:62718/dictionary/import", {
        method: "POST",
        body: form
      })
        .then(function(res) {
          return res.json();
        })
        .then(data => {
          this.importLoading = false;
          if (data.error) {
            this.importError = data.error;
            return;
          }
          this.importResult = data;
          this.dictSources = data.sources || this.dictSources;
          input.value = "";
        })
        .catch(err => {
          this.importLoading = false;
          this.importError = String(err);
        });
    },
    removeDictSource(source) {
      fetch(
        "http://localhost:62718/dictionary/sources/" + encodeURIComponent(source),
        { method: "DELETE" }
      )
        .then(function(res) {
          return res.json();
        })
        .then(data => {
          this.dictSources = data.sources || [];
          this.importResult = null;
        });
    }
  }
});

app.getPreference();
app.loadSubstitutions();
app.loadDictSources();
