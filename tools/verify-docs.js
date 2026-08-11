/*
 * verify-docs.js — Check the built documentation site in a real browser.
 *                  실제 브라우저에서 빌드된 문서 사이트를 검사합니다.
 *
 * WHY / 이유
 *
 * Grepping the built HTML proves the markup is there. It cannot prove that mermaid
 * actually draws a diagram, that the copy buttons appear, that the Korean font is the
 * one being used, or that dark mode is wired up — all of that is client-side. This
 * loads the site in headless Chromium and asserts against the live DOM and computed
 * styles instead.
 * 빌드된 HTML 을 grep 하면 마크업 존재는 증명됩니다. 하지만 mermaid 가 실제로 다이어그램을
 * 그리는지, 복사 버튼이 나타나는지, 한글 폰트가 실제로 적용되는지, 다크 모드가 연결되어
 * 있는지는 증명할 수 없습니다. 모두 클라이언트 사이드이기 때문입니다. 이 스크립트는
 * 헤드리스 Chromium 으로 사이트를 열어 실제 DOM 과 계산된 스타일에 대해 검사합니다.
 *
 * Run via Docker so nothing is installed locally / 로컬 설치 없이 Docker 로 실행:
 *   see tools/verify-docs.sh
 */
const { chromium } = require('playwright');

const BASE = process.env.DOCS_URL || 'http://127.0.0.1:8099';
const SHOTS = process.env.SHOT_DIR || '/shots';

const results = [];
function check(name, pass, detail) {
  results.push({ name, pass, detail });
  const mark = pass ? '  [32mPASS[0m' : '  [31mFAIL[0m';
  console.log(`${mark} ${name}${detail ? ` — ${detail}` : ''}`);
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });

  // ---------------------------------------------------------------------------
  // Layout / 레이아웃
  // ---------------------------------------------------------------------------
  await page.goto(`${BASE}/`, { waitUntil: 'networkidle' });

  const tabs = await page.$$eval('.md-tabs__link', els =>
    els.map(e => e.textContent.trim()).filter(Boolean));
  const uniqueTabs = [...new Set(tabs)];
  check('top-level menu is in the header / 최상위 메뉴가 상단에',
    uniqueTabs.length === 5, uniqueTabs.join(', '));

  // The requested layout has no right-hand column at all.
  // 요청된 레이아웃에는 우측 열이 전혀 없습니다.
  const rightBars = await page.$$('.md-sidebar--secondary');
  check('no right-hand menu bar / 우측 메뉴바 없음',
    rightBars.length === 0, `${rightBars.length} element(s)`);

  const leftNavVisible = await page.isVisible('.md-sidebar--primary');
  check('left sidebar present / 좌측 사이드바 존재', leftNavVisible);

  await page.screenshot({ path: `${SHOTS}/01-home-light.png`, fullPage: false });

  // ---------------------------------------------------------------------------
  // Sub-navigation in the left sidebar / 좌측 사이드바의 하위 메뉴
  // ---------------------------------------------------------------------------
  await page.goto(`${BASE}/engines/`, { waitUntil: 'networkidle' });
  const engineLinks = await page.$$eval('.md-sidebar--primary .md-nav__link', els =>
    els.map(e => e.textContent.trim()));
  const hasEngineChildren = ['Oracle', 'PostgreSQL', 'Vertica', 'ClickHouse', 'StarRocks']
    .every(n => engineLinks.some(l => l.includes(n)));
  check('sub-menu items in the left sidebar / 하위 메뉴가 좌측 사이드바에',
    hasEngineChildren, `${engineLinks.length} links`);

  const integrated = await page.$$('.md-nav--integrated');
  check('per-page toc integrated into left nav / 페이지 목차가 좌측에 통합',
    integrated.length > 0, `${integrated.length} element(s)`);
  await page.screenshot({ path: `${SHOTS}/02-engines-subnav.png` });

  // ---------------------------------------------------------------------------
  // Mermaid actually renders / mermaid 실제 렌더링
  // ---------------------------------------------------------------------------
  await page.goto(`${BASE}/reference/schema/`, { waitUntil: 'networkidle' });
  // Material renders the diagram into a CLOSED shadow root:
  //   const host = div(); host.attachShadow({mode:"closed"}).innerHTML = svg
  // so querySelector('.mermaid svg') can never see it, and el.shadowRoot is null.
  // Measure the host's laid-out size instead: an unrendered or failed diagram
  // collapses to roughly zero height, a drawn one does not.
  // Material 은 다이어그램을 CLOSED 섀도 루트에 렌더링하므로
  // querySelector('.mermaid svg') 로는 볼 수 없고 el.shadowRoot 도 null 입니다. 대신 호스트의
  // 레이아웃 크기를 측정합니다. 렌더링되지 않았거나 실패한 다이어그램은 높이가 거의 0 으로
  // 붕괴하지만, 그려진 다이어그램은 그렇지 않습니다.
  let mermaidOk = false, mermaidDetail = 'no .mermaid host found';
  try {
    await page.waitForSelector('.mermaid', { timeout: 20000 });
    await page.waitForFunction(
      () => [...document.querySelectorAll('.mermaid')]
        .every(el => el.getBoundingClientRect().height > 50),
      { timeout: 20000 });
    const boxes = await page.$$eval('.mermaid', els => els.map(el => {
      const r = el.getBoundingClientRect();
      return { w: Math.round(r.width), h: Math.round(r.height), shadow: el.shadowRoot === null };
    }));
    // Size alone is not enough: a diagram with too many edges renders as a wide, very
    // short band that is technically drawn but unreadable. An extreme aspect ratio is
    // the signature of that, so treat it as a failure.
    // 크기만으로는 부족합니다. 간선이 너무 많은 다이어그램은 넓고 매우 낮은 띠로
    // 렌더링되어 기술적으로는 그려졌지만 읽을 수 없습니다. 극단적인 종횡비가 그 특징이므로
    // 실패로 처리합니다.
    const legible = b => b.w > 100 && b.h > 50 && (b.w / b.h) < 8;
    mermaidOk = boxes.length > 0 && boxes.every(legible);
    mermaidDetail = boxes.map(b => `${b.w}x${b.h}px (ratio ${(b.w / b.h).toFixed(1)})`).join(', ')
      + (boxes.every(b => b.shadow) ? ' [closed shadow root]' : '')
      + (boxes.every(legible) ? '' : ' — squashed, too many edges to read');
  } catch (e) { mermaidDetail = 'host never gained height — diagram did not draw'; }
  check('mermaid diagram draws / mermaid 다이어그램 렌더링', mermaidOk, mermaidDetail);
  await page.screenshot({ path: `${SHOTS}/03-schema-mermaid.png`, fullPage: false });

  // ---------------------------------------------------------------------------
  // Code blocks, copy buttons, content tabs / 코드 블록·복사 버튼·콘텐츠 탭
  // ---------------------------------------------------------------------------
  await page.goto(`${BASE}/getting-started/quickstart/`, { waitUntil: 'networkidle' });
  const preCount = (await page.$$('pre')).length;
  check('code blocks render as blocks / 코드 블록이 블록으로 렌더링',
    preCount > 0, `${preCount} <pre>`);

  // Material renamed this control in 9.7: .md-clipboard became
  // .md-code__button[data-md-type=copy] inside a .md-code__nav. Accept either so the
  // check does not silently pass or fail on a theme upgrade.
  // Material 9.7 에서 이 컨트롤 이름이 바뀌었습니다. .md-clipboard 가 .md-code__nav 안의
  // .md-code__button[data-md-type=copy] 로 변경되었습니다. 테마 업그레이드 때 검사가 조용히
  // 통과하거나 실패하지 않도록 두 형태를 모두 허용합니다.
  const copyButtons = await page.$$eval(
    '.md-clipboard, .md-code__button[data-md-type="copy"]', els => els.length);
  check('copy buttons present / 복사 버튼 존재', copyButtons > 0, `${copyButtons} buttons`);

  const tabLabels = await page.$$eval('.tabbed-labels > label', els =>
    els.map(e => e.textContent.trim()));
  check('content tabs render / 콘텐츠 탭 렌더링',
    tabLabels.length >= 5, tabLabels.slice(0, 6).join(', '));
  await page.screenshot({ path: `${SHOTS}/04-quickstart-tabs.png`, fullPage: false });

  // ---------------------------------------------------------------------------
  // Korean typography / 한글 타이포그래피
  //
  // The custom stylesheet only matters if the browser is really resolving a Korean
  // face, and if keep-all is applied to prose but not to code.
  // 브라우저가 실제로 한글 서체를 사용하고, keep-all 이 산문에만 적용될 때에만 사용자
  // 정의 스타일시트가 의미가 있습니다.
  // ---------------------------------------------------------------------------
  const typography = await page.evaluate(() => {
    const p = [...document.querySelectorAll('.md-typeset p')]
      .find(el => /[가-힣]/.test(el.textContent));
    const code = document.querySelector('.md-typeset pre code');
    return {
      hasKoreanParagraph: !!p,
      family: p ? getComputedStyle(p).fontFamily : '',
      wordBreak: p ? getComputedStyle(p).wordBreak : '',
      codeFamily: code ? getComputedStyle(code).fontFamily : '',
      codeWordBreak: code ? getComputedStyle(code).wordBreak : '',
    };
  });
  const koreanFace = /Apple SD Gothic Neo|Pretendard|Malgun Gothic|Noto Sans KR/i
    .test(typography.family);
  check('Korean face in the resolved font stack / 한글 서체가 폰트 스택에 포함',
    koreanFace, typography.family.split(',').slice(0, 4).join(',').trim());
  check('prose uses word-break: keep-all / 산문에 keep-all 적용',
    typography.wordBreak === 'keep-all', typography.wordBreak);
  check('code is NOT keep-all / 코드에는 keep-all 미적용',
    typography.codeWordBreak === 'normal', typography.codeWordBreak);
  check('code stays monospaced / 코드는 고정폭 유지',
    /mono|Menlo|Consolas/i.test(typography.codeFamily),
    typography.codeFamily.split(',')[0]);

  // ---------------------------------------------------------------------------
  // Admonitions and status pills / admonition 과 상태 배지
  // ---------------------------------------------------------------------------
  await page.goto(`${BASE}/`, { waitUntil: 'networkidle' });
  const adm = await page.$$eval('.admonition', els => els.map(e => e.className));
  check('admonitions render with styling / admonition 스타일 적용',
    adm.length > 0, adm.join(' | '));

  const pillColour = await page.evaluate(() => {
    const el = document.querySelector('.pill.pass');
    if (!el) return null;
    const s = getComputedStyle(el);
    return { bg: s.backgroundColor, colour: s.color, radius: s.borderRadius };
  });
  // Cards are easy to break silently: markdown inside a div wraps each link in a <p>,
  // so a selector written against the link as a direct child matches nothing and the
  // card renders as bare text. Assert the computed border instead of the markup.
  // 카드는 조용히 깨지기 쉽습니다. div 안의 마크다운이 각 링크를 <p> 로 감싸므로, 링크를
  // 직접 자식으로 가정한 선택자는 아무것도 매칭하지 못하고 카드가 맨 텍스트로 렌더링됩니다.
  // 마크업이 아니라 계산된 테두리를 검사합니다.
  const card = await page.evaluate(() => {
    const a = document.querySelector('.card-grid a');
    if (!a) return null;
    const s = getComputedStyle(a);
    return { border: s.borderTopWidth, colour: s.borderTopColor, pad: s.paddingTop, display: s.display };
  });
  check('landing cards are styled as cards / 랜딩 카드가 카드로 스타일링',
    card !== null && parseFloat(card.border) >= 1 && parseFloat(card.pad) > 0,
    card ? `border ${card.border} ${card.colour}, padding ${card.pad}` : 'no .card-grid a');

  check('custom stylesheet applied to pills / 사용자 정의 스타일 적용',
    pillColour !== null && pillColour.bg !== 'rgba(0, 0, 0, 0)',
    pillColour ? `bg ${pillColour.bg}, radius ${pillColour.radius}` : 'no .pill.pass');

  // ---------------------------------------------------------------------------
  // Dark mode / 다크 모드
  // ---------------------------------------------------------------------------
  const dark = await browser.newContext({
    viewport: { width: 1440, height: 1000 }, colorScheme: 'dark',
  });
  const darkPage = await dark.newPage();
  await darkPage.goto(`${BASE}/`, { waitUntil: 'networkidle' });
  const scheme = await darkPage.evaluate(() =>
    document.body.getAttribute('data-md-color-scheme')
    || document.documentElement.getAttribute('data-md-color-scheme'));
  check('dark mode selects the slate scheme / 다크 모드가 slate 적용',
    scheme === 'slate', String(scheme));
  await darkPage.screenshot({ path: `${SHOTS}/05-home-dark.png`, fullPage: false });

  // ---------------------------------------------------------------------------
  // Search index actually built / 검색 인덱스 생성 확인
  // ---------------------------------------------------------------------------
  await page.goto(`${BASE}/`, { waitUntil: 'networkidle' });
  const searchHits = await page.evaluate(async () => {
    const r = await fetch('/search/search_index.json');
    if (!r.ok) return null;
    const j = await r.json();
    const korean = j.docs.filter(d => /[가-힣]/.test(d.text || '')).length;
    return { docs: j.docs.length, korean };
  });
  check('search index includes Korean text / 검색 인덱스에 한글 포함',
    searchHits !== null && searchHits.korean > 0,
    searchHits ? `${searchHits.docs} docs, ${searchHits.korean} with Korean` : 'no index');

  // ---------------------------------------------------------------------------
  // Every nav page returns 200 / 모든 내비게이션 페이지 200 확인
  // ---------------------------------------------------------------------------
  const paths = [
    '/', '/getting-started/quickstart/', '/getting-started/commands/',
    '/getting-started/datagen/', '/engines/', '/engines/oracle/', '/engines/postgres/',
    '/engines/vertica/', '/engines/clickhouse/', '/engines/starrocks/',
    '/verification/', '/verification/schema-divergence/', '/reference/schema/',
    '/reference/methodology/', '/reference/licensing/', '/404/',
  ];
  const bad = [];
  for (const p of paths) {
    const resp = await page.goto(`${BASE}${p}`, { waitUntil: 'domcontentloaded' });
    if (!resp || resp.status() !== 200) bad.push(`${p} (${resp ? resp.status() : 'no response'})`);
  }
  check('all nav pages return 200 / 모든 페이지 200',
    bad.length === 0, bad.length ? bad.join(', ') : `${paths.length} pages`);

  // Console errors would hide broken client-side behaviour.
  // 콘솔 오류는 깨진 클라이언트 동작을 숨깁니다.
  // Only uncaught JS errors matter. Material also requests
  // api.github.com/repos/<repo>/releases/latest for the header badge, which 404s on a
  // repo with no releases: a console network message, not a page error, and not ours.
  // 처리되지 않은 JS 오류만 의미가 있습니다. Material 은 헤더 배지를 위해
  // api.github.com/repos/<repo>/releases/latest 도 요청하는데, 릴리스가 없는 저장소에서는
  // 404 가 됩니다. 이는 콘솔 네트워크 메시지이며 페이지 오류가 아니고 우리 문제도 아닙니다.
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.goto(`${BASE}/reference/schema/`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(1500);
  check('no uncaught JavaScript errors / 처리되지 않은 JS 오류 없음',
    errors.length === 0, errors.slice(0, 2).join(' | ') || 'none');

  await browser.close();

  const failed = results.filter(r => !r.pass);
  console.log(`\n  ${results.length - failed.length}/${results.length} checks passed`);
  if (failed.length) {
    console.log(`  failed: ${failed.map(f => f.name).join('; ')}`);
    process.exit(1);
  }
})().catch(e => { console.error('fatal:', e); process.exit(2); });
