/**
 * separator.service.js
 * Servicio de separación de voz e instrumental con HT-Demucs v4.
 */
const { processSeparation } = require("./vocalSeparator");
const separatorRepository = require("../repository/separator.repository");

class SeparatorService {
  constructor() {
    this.repository = separatorRepository;
  }

  async separateAudio(params) {
    return processSeparation(params);
  }

  findStemById(id) {
    return this.repository.findById(id);
  }
}

module.exports = new SeparatorService();
