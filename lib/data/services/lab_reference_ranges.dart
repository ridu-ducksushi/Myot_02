/// 검사 항목별 기준치 (Reference Ranges) 제공 유틸리티
/// 
/// 강아지와 고양이의 검사 항목별 정상 기준치를 제공합니다.
/// DRY 원칙 준수를 위해 단일 진실의 원천(Single Source of Truth)으로 사용됩니다.
class LabReferenceRanges {
  LabReferenceRanges._(); // Private constructor to prevent instantiation

  /// 강아지 기준치 맵
  static Map<String, String> get dogRanges => Map.unmodifiable(_dogRanges);

  /// 고양이 기준치 맵
  static Map<String, String> get catRanges => Map.unmodifiable(_catRanges);

  /// 펫 종류에 따라 적절한 기준치를 반환합니다.
  /// 
  /// [species] 펫 종류 ('dog', 'cat' 등)
  /// [testItem] 검사 항목명
  /// 
  /// Returns 펫 종류에 맞는 기준치, 없으면 빈 문자열
  static String getReference(String species, String testItem) {
    final isCat = species.toLowerCase() == 'cat';
    if (isCat) {
      return _catRanges[testItem] ?? _dogRanges[testItem] ?? '';
    }
    return _dogRanges[testItem] ?? _catRanges[testItem] ?? '';
  }

  /// 강아지 기준치 (ABC 순)
  static final Map<String, String> _dogRanges = {
    'ALB': '2.6~4.0', // 알부민
    'ALP': '20~150',
    'ALT GPT': '10~100',
    'AST GOT': '15~66',
    'BUN': '9.2~29.2',
    'Ca': '9.0~12.0',
    'CK': '59~895', // 크레아틴 키나아제
    'Cl': '106~120',
    'CREA': '0.5~1.6', // 크레아티닌
    'GGT': '0~13', // 감마글루타밀전이효소
    'GLU': '65~118',
    'K': '3.6~5.5',
    'LIPA': '100~750',
    'Na': '140~155',
    'NH3': '16~90',
    'PHOS': '2.5~6.8',
    'TBIL': '0.1~0.6',
    'T-CHOL': '110~320',
    'TG': '20~150', // 중성지방
    'TPRO': '5.4~7.8', // 총단백
    'Na/K': '27~38',
    'ALB/GLB': '0.8~1.5',
    'BUN/CRE': '10~27',
    'GLOB': '2.0~4.5',
    'vAMY-P': '500~1500',
    'SDMA': '~14',
    'HCT': '37~55',
    'HGB': '12~18',
    'MCH': '19~23',
    'MCHC': '32~36',
    'MCV': '60~77',
    'MPV': '7~12',
    'PLT': '200~500',
    'RBC': '5.5~8.5',
    'RDW-CV': '14~18',
    'WBC': '6~17',
    'WBC-GRAN(#)': '4~12',
    'WBC-GRAN(%)': '0~100',
    'WBC-LYM(#)': '1~4.8',
    'WBC-LYM(%)': '0~100',
    'WBC-MONO(#)': '0~1.3',
    'WBC-MONO(%)': '0~100',
    'WBC-EOS(#)': '0~1.2',
    'WBC-EOS(%)': '0~100',
  };

  /// 고양이 기준치 (ABC 순)
  static final Map<String, String> _catRanges = {
    'ALB': '2.3~3.5', // 알부민
    'ALP': '9~53',
    'ALT GPT': '20~120',
    'AST GOT': '18~51',
    'BUN': '17.6~32.8',
    'Ca': '8.8~11.9',
    'CK': '87~309', // 크레아틴 키나아제
    'Cl': '107~120',
    'CREA': '0.8~1.8', // Creatinine
    'GGT': '1~10', // 글로불린
    'GLU': '71~148',
    'K': '3.4~4.6',
    'LIPA': '0~30',
    'Na': '147~156',
    'NH3': '23~78',
    'PHOS': '2.6~6.0',
    'TBIL': '0.1~0.4',
    'T-CHOL': '89~176',
    'TG': '17~104', // 총빌리루빈
    'TPRO': '5.7~7.8', // 중성지방
    'Na/K': '33.6~44.2', // 총단백
    'ALB/GLB': '0.4~1.1',
    'BUN/CRE': '17.5~21.9',
    'GLOB': '2.7~5.2',
    'vAMY-P': '200~1900',
    'SDMA': '~14',
    'HCT': '27~47',
    'HGB': '8~17',
    'MCH': '13~17',
    'MCHC': '31~36',
    'MCV': '40~55',
    'MPV': '6.5~15',
    'PLT': '180~430',
    'RBC': '5~10',
    'RDW-CV': '17~22',
    'WBC': '5~11',
    'WBC-GRAN(#)': '3~12',
    'WBC-GRAN(%)': '0~100',
    'WBC-LYM(#)': '1~4',
    'WBC-LYM(%)': '0~100',
    'WBC-MONO(#)': '0~0.5',
    'WBC-MONO(%)': '0~100',
    'WBC-EOS(#)': '0~0.6',
    'WBC-EOS(%)': '0~100',
  };
}

