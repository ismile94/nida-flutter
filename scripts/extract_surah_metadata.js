const fs = require('fs');
const path = require('path');
const trPath = path.join(__dirname, '../../utils/locales/tr.json');
const enPath = path.join(__dirname, '../../utils/locales/en.json');
const tr = JSON.parse(fs.readFileSync(trPath, 'utf8'));
const en = JSON.parse(fs.readFileSync(enPath, 'utf8'));
const out = {
  tr: {
    surahDescriptions: tr.surahDescriptions || {},
    surahRevelationDates: tr.surahRevelationDates || {},
    surahMainThemes: tr.surahMainThemes || {},
  },
  en: {
    surahDescriptions: en.surahDescriptions || {},
    surahRevelationDates: en.surahRevelationDates || {},
    surahMainThemes: en.surahMainThemes || {},
  },
};
const outPath = path.join(__dirname, '../assets/data/surah_metadata.json');
fs.writeFileSync(outPath, JSON.stringify(out), 'utf8');
console.log('Written', outPath);
