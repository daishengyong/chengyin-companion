import Foundation

#if canImport(CompanionContracts)
import CompanionContracts
#endif

enum ContentPackProjectionEditor {
    static func initialReceipt(
        packID: String,
        asset: ContentPackAsset,
        appVersion: String
    ) throws -> CompanionProjectionAuthoringReceipt {
        let durationMs = max(asset.durationMs ?? 4_000, 1_000)
        let previewItems = Dictionary(
            uniqueKeysWithValues: ContentPackProjectionPreview.items(for: asset)
                .map { ($0.mode.rawValue, $0) }
        )
        var tracks: [String: [CompanionMediaFocalKeyframe]] = [:]
        var safeAreas: [String: CompanionMediaSafeArea] = [:]
        for mode in ["pet", "stage", "fullscreen"] {
            guard let preview = previewItems[mode] else { continue }
            if let track = preview.projection.focalTrack {
                tracks[mode] = track.keyframes
            } else {
                let fallback = mode == "pet"
                    ? CompanionMediaCropAnchor(x: 0.5, y: 0.5, scale: 2)
                    : CompanionMediaCropAnchor(x: 0.5, y: 0.5, scale: 1)
                let anchor = preview.projection.anchor ?? fallback
                tracks[mode] = [
                    CompanionMediaFocalKeyframe(
                        timeMs: 0,
                        x: anchor.x,
                        y: anchor.y,
                        scale: anchor.scale
                    ),
                    CompanionMediaFocalKeyframe(
                        timeMs: durationMs,
                        x: anchor.x,
                        y: anchor.y,
                        scale: anchor.scale
                    )
                ]
            }
            if let safeArea = preview.projection.safeArea {
                safeAreas[mode] = safeArea
            }
        }
        let receipt = CompanionProjectionAuthoringReceipt(
            packID: packID,
            assetID: asset.id,
            generatedForAppVersion: appVersion,
            focalTracks: tracks,
            safeAreas: safeAreas
        )
        try receipt.validate(durationMs: durationMs)
        return receipt
    }

    static func render(
        packID: String,
        asset: ContentPackAsset,
        assetURL: URL,
        appVersion: String,
        preferredLocale: String
    ) throws -> String {
        let receipt = try initialReceipt(
            packID: packID,
            asset: asset,
            appVersion: appVersion
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(receipt).base64EncodedString()
        let durationMs = max(asset.durationMs ?? 4_000, 1_000)
        let copy = Copy(chinese: preferredLocale.lowercased().hasPrefix("zh"))
        let source = escape(assetURL.absoluteString)

        return """
        <!doctype html>
        <html lang="\(copy.language)">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <meta http-equiv="Content-Security-Policy" content="default-src 'none'; media-src file: data: blob:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src data:; connect-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'">
          <title>\(escape(copy.title)) · \(escape(asset.id))</title>
          <style>
            :root { color-scheme: dark; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background:#0b0b10; color:#f7f4fb; }
            * { box-sizing:border-box; }
            body { margin:0; min-height:100vh; background:radial-gradient(circle at 12% 0,#4d294e 0,#15131b 34%,#0b0b10 72%); }
            a.skip { position:absolute; left:-9999px; } a.skip:focus { left:16px; top:16px; z-index:10; padding:10px; background:#fff; color:#111; }
            header { padding:30px clamp(18px,4vw,54px) 20px; border-bottom:1px solid #ffffff18; }
            .eyebrow { color:#ff9bd5; font-size:12px; font-weight:750; letter-spacing:.14em; text-transform:uppercase; }
            h1 { margin:8px 0 6px; font-size:clamp(26px,4vw,44px); letter-spacing:-.035em; }
            header p { margin:0; max-width:850px; color:#bdb5c7; line-height:1.55; }
            .privacy { display:inline-flex; margin-top:14px; padding:7px 10px; border:1px solid #64e5b852; border-radius:999px; color:#8ef3cf; font-size:12px; }
            main { display:grid; grid-template-columns:minmax(330px,1.45fr) minmax(300px,.75fr); gap:22px; padding:24px clamp(18px,4vw,54px) 50px; }
            .panel { min-width:0; border:1px solid #ffffff1c; border-radius:22px; background:#17161f; box-shadow:0 24px 80px #0007; }
            .preview-panel { padding:18px; align-self:start; }
            .mode-tabs, .actions { display:flex; flex-wrap:wrap; gap:8px; }
            button { min-height:40px; border:1px solid #ffffff25; border-radius:12px; padding:9px 13px; color:#f7f4fb; background:#26232f; font:inherit; cursor:pointer; }
            button:hover { background:#302b3a; } button[aria-pressed="true"], button.primary { border-color:#ff93cf; background:#5d3154; }
            button:disabled { opacity:.45; cursor:not-allowed; }
            .viewport-wrap { display:grid; place-items:center; min-height:320px; margin:16px 0; padding:18px; border-radius:18px; background:#050507; }
            .viewport { position:relative; overflow:hidden; width:100%; max-height:62vh; aspect-ratio:16/9; border:1px solid #ffffff28; border-radius:16px; background:#000; }
            .viewport.pet { width:min(62vh,100%); aspect-ratio:1; }
            video { position:absolute; max-width:none; max-height:none; background:transparent; }
            .safe-area { position:absolute; z-index:2; pointer-events:none; border:2px dashed #62f0bd; border-radius:9px; box-shadow:0 0 0 9999px #00000020; }
            .crosshair { position:absolute; z-index:3; width:14px; height:14px; margin:-7px; border:2px solid #ff78c1; border-radius:50%; pointer-events:none; box-shadow:0 0 0 2px #0008; }
            .timeline { display:grid; grid-template-columns:auto 1fr auto; gap:10px; align-items:center; }
            input[type="range"] { width:100%; accent-color:#ff82c8; }
            .keyframes { display:flex; gap:7px; overflow:auto; padding:10px 0 3px; }
            .keyframes button { flex:0 0 auto; min-height:34px; padding:6px 10px; font-size:12px; }
            .editor-panel { padding:20px; }
            .group { padding:15px 0; border-bottom:1px solid #ffffff14; }
            .group:first-child { padding-top:0; } .group:last-child { border:0; }
            h2 { margin:0 0 12px; font-size:17px; }
            .field { display:grid; grid-template-columns:90px 1fr 70px; gap:9px; align-items:center; margin:11px 0; }
            .field label { color:#cfc8d7; font-size:13px; }
            input[type="number"], textarea { width:100%; border:1px solid #ffffff24; border-radius:10px; padding:9px; color:#fff; background:#0e0d13; font:inherit; }
            .switch { display:flex; gap:10px; align-items:center; }
            textarea { min-height:150px; resize:vertical; font:12px ui-monospace,SFMono-Regular,Menlo,monospace; line-height:1.45; }
            .status { min-height:42px; margin:12px 0 0; padding:10px 12px; border-radius:11px; color:#9af1cf; background:#0d2c2366; }
            .status.error { color:#ffd1d8; background:#4b1d2866; }
            .hint { color:#9f98aa; font-size:12px; line-height:1.5; }
            @media (max-width:900px) { main { grid-template-columns:1fr; } .viewport-wrap { min-height:240px; } }
            @media (prefers-reduced-motion:reduce) { * { scroll-behavior:auto!important; transition:none!important; animation:none!important; } }
          </style>
        </head>
        <body data-network="disabled">
          <a class="skip" href="#controls">\(escape(copy.skip))</a>
          <header>
            <div class="eyebrow">Chengyin · Content Pack v2</div>
            <h1>\(escape(copy.title))</h1>
            <p>\(escape(copy.subtitle)) <strong>\(escape(packID))</strong> · <strong>\(escape(asset.id))</strong></p>
            <span class="privacy">\(escape(copy.privacy))</span>
          </header>
          <main id="controls">
            <section class="panel preview-panel" aria-labelledby="preview-title">
              <h2 id="preview-title">\(escape(copy.preview))</h2>
              <div class="mode-tabs" role="group" aria-label="\(escape(copy.mode))">
                <button type="button" data-mode="pet">Pet</button>
                <button type="button" data-mode="stage">Stage</button>
                <button type="button" data-mode="fullscreen">Fullscreen</button>
              </div>
              <div class="viewport-wrap">
                <div id="viewport" class="viewport">
                  <video id="video" controls playsinline muted preload="metadata" aria-label="\(escape(copy.videoLabel))" src="\(source)"></video>
                  <div id="safe-overlay" class="safe-area" hidden aria-hidden="true"></div>
                  <div id="crosshair" class="crosshair" aria-hidden="true"></div>
                </div>
              </div>
              <div class="timeline">
                <span>0s</span>
                <input id="time" type="range" min="0" max="\(durationMs)" step="10" value="0" aria-label="\(escape(copy.timeline))">
                <output id="time-output" for="time">0.00s</output>
              </div>
              <div id="keyframes" class="keyframes" aria-label="\(escape(copy.keyframes))"></div>
              <div class="actions">
                <button type="button" id="add-keyframe">\(escape(copy.addKeyframe))</button>
                <button type="button" id="delete-keyframe">\(escape(copy.deleteKeyframe))</button>
                <button type="button" id="reset-mode">\(escape(copy.resetMode))</button>
              </div>
            </section>
            <section class="panel editor-panel" aria-labelledby="editor-title">
              <h2 id="editor-title">\(escape(copy.controls))</h2>
              <div class="group" id="anchor-controls">
                <div class="field"><label for="anchor-x">X</label><input id="anchor-x" type="range" min="0" max="1" step="0.001"><input id="anchor-x-number" type="number" min="0" max="1" step="0.001"></div>
                <div class="field"><label for="anchor-y">Y</label><input id="anchor-y" type="range" min="0" max="1" step="0.001"><input id="anchor-y-number" type="number" min="0" max="1" step="0.001"></div>
                <div class="field"><label for="anchor-scale">\(escape(copy.scale))</label><input id="anchor-scale" type="range" min="1" max="8" step="0.01"><input id="anchor-scale-number" type="number" min="1" max="8" step="0.01"></div>
              </div>
              <div class="group">
                <label class="switch"><input id="safe-enabled" type="checkbox"> <span>\(escape(copy.safeArea))</span></label>
                <div id="safe-controls">
                  <div class="field"><label for="safe-x">X</label><input id="safe-x" type="range" min="0" max="1" step="0.001"><input id="safe-x-number" type="number" min="0" max="1" step="0.001"></div>
                  <div class="field"><label for="safe-y">Y</label><input id="safe-y" type="range" min="0" max="1" step="0.001"><input id="safe-y-number" type="number" min="0" max="1" step="0.001"></div>
                  <div class="field"><label for="safe-width">\(escape(copy.width))</label><input id="safe-width" type="range" min="0.01" max="1" step="0.001"><input id="safe-width-number" type="number" min="0.01" max="1" step="0.001"></div>
                  <div class="field"><label for="safe-height">\(escape(copy.height))</label><input id="safe-height" type="range" min="0.01" max="1" step="0.001"><input id="safe-height-number" type="number" min="0.01" max="1" step="0.001"></div>
                </div>
                <p class="hint">\(escape(copy.safeHint))</p>
              </div>
              <div class="group">
                <h2>\(escape(copy.receipt))</h2>
                <textarea id="receipt" readonly aria-label="\(escape(copy.receipt))"></textarea>
                <div class="actions">
                  <button type="button" id="copy-receipt">\(escape(copy.copy))</button>
                  <button type="button" id="download-receipt" class="primary">\(escape(copy.download))</button>
                </div>
                <p class="hint">\(escape(copy.applyHint))</p>
                <div id="status" class="status" role="status" aria-live="polite"></div>
              </div>
            </section>
          </main>
          <script id="initial-state" type="application/octet-stream">\(payload)</script>
          <script>
          (() => {
            'use strict';
            const initial = JSON.parse(atob(document.getElementById('initial-state').textContent.trim()));
            const state = JSON.parse(JSON.stringify(initial));
            const original = JSON.parse(JSON.stringify(initial));
            const modes = ['pet','stage','fullscreen'];
            let activeMode = 'pet';
            let selectedIndex = 0;
            const $ = id => document.getElementById(id);
            const clamp = (value, low, high) => Math.min(Math.max(value, low), high);
            const round = value => Math.round(value * 10000) / 10000;

            function anchorAt(track, timeMs) {
              if (timeMs <= track[0].timeMs) return {...track[0]};
              const last = track[track.length - 1];
              if (timeMs >= last.timeMs) return {...last};
              const upperIndex = track.findIndex(frame => frame.timeMs >= timeMs);
              const lower = track[upperIndex - 1], upper = track[upperIndex];
              const progress = (timeMs - lower.timeMs) / (upper.timeMs - lower.timeMs);
              return {
                timeMs,
                x: lower.x + (upper.x - lower.x) * progress,
                y: lower.y + (upper.y - lower.y) * progress,
                scale: lower.scale + (upper.scale - lower.scale) * progress
              };
            }

            function projectionFrame(anchor) {
              const scale = anchor.scale * 100;
              const minimumOffset = 100 - scale;
              return {
                left: clamp(50 - anchor.x * scale, minimumOffset, 0),
                top: clamp(50 - anchor.y * scale, minimumOffset, 0),
                width: scale,
                height: scale
              };
            }

            function safeAreaVisible(area, anchor) {
              if (!area || area.x < 0 || area.y < 0 || area.width <= 0 || area.height <= 0 || area.x + area.width > 1 || area.y + area.height > 1) return false;
              const extent = 1 / anchor.scale;
              const maxOrigin = 1 - extent;
              const visibleX = clamp(anchor.x - extent / 2, 0, maxOrigin);
              const visibleY = clamp(anchor.y - extent / 2, 0, maxOrigin);
              const epsilon = 0.000001;
              return area.x + epsilon >= visibleX && area.y + epsilon >= visibleY && area.x + area.width <= visibleX + extent + epsilon && area.y + area.height <= visibleY + extent + epsilon;
            }

            function geometrySelfCheck() {
              const top = projectionFrame({x:.5,y:.2,scale:2}).top;
              const bottom = projectionFrame({x:.5,y:.8,scale:2}).top;
              const edge = projectionFrame({x:.05,y:.05,scale:3});
              return top === 0 && bottom === -100 && edge.left === 0 && edge.top === 0;
            }

            function bindPair(rangeID, numberID, onValue) {
              const range = $(rangeID), number = $(numberID);
              const update = source => {
                const value = clamp(Number(source.value), Number(range.min), Number(range.max));
                range.value = String(value); number.value = String(round(value)); onValue(value);
              };
              range.addEventListener('input', () => update(range));
              number.addEventListener('change', () => update(number));
              return value => { range.value = String(value); number.value = String(round(value)); };
            }

            const setAnchorX = bindPair('anchor-x','anchor-x-number', value => { currentFrame().x = value; refresh(); });
            const setAnchorY = bindPair('anchor-y','anchor-y-number', value => { currentFrame().y = value; refresh(); });
            const setAnchorScale = bindPair('anchor-scale','anchor-scale-number', value => { currentFrame().scale = value; refresh(); });
            const safeSetters = {
              x: bindPair('safe-x','safe-x-number', value => { safeArea().x = value; refresh(); }),
              y: bindPair('safe-y','safe-y-number', value => { safeArea().y = value; refresh(); }),
              width: bindPair('safe-width','safe-width-number', value => { safeArea().width = value; refresh(); }),
              height: bindPair('safe-height','safe-height-number', value => { safeArea().height = value; refresh(); })
            };

            function track() { return state.focalTracks[activeMode]; }
            function currentFrame() { return track()[selectedIndex]; }
            function safeArea() {
              if (!state.safeAreas[activeMode]) state.safeAreas[activeMode] = {x:.25,y:.25,width:.5,height:.5};
              return state.safeAreas[activeMode];
            }
            function setStatus(message, error=false) { $('status').textContent = message; $('status').classList.toggle('error', error); }
            function formatTime(ms) { return (ms / 1000).toFixed(2) + 's'; }

            function validate() {
              for (const mode of modes) {
                const frames = state.focalTracks[mode];
                if (!Array.isArray(frames) || frames.length < 2 || frames.length > 32 || frames[0].timeMs !== 0) return `\(escape(copy.invalidTrack)) ${mode}`;
                for (let i=0;i<frames.length;i++) {
                  const frame = frames[i];
                  if (i && frame.timeMs <= frames[i-1].timeMs) return `\(escape(copy.invalidTrack)) ${mode}`;
                  if (frame.x < 0 || frame.x > 1 || frame.y < 0 || frame.y > 1 || frame.scale < 1 || frame.scale > 8) return `\(escape(copy.invalidTrack)) ${mode}`;
                }
                const area = state.safeAreas[mode];
                if (area && !frames.every(frame => safeAreaVisible(area, frame))) return `\(escape(copy.safeOutside)) ${mode}`;
              }
              return null;
            }

            function receiptJSON() {
              const normalized = JSON.parse(JSON.stringify(state));
              for (const mode of modes) normalized.focalTracks[mode].forEach(frame => { frame.x=round(frame.x); frame.y=round(frame.y); frame.scale=round(frame.scale); });
              for (const mode of Object.keys(normalized.safeAreas)) for (const key of ['x','y','width','height']) normalized.safeAreas[mode][key]=round(normalized.safeAreas[mode][key]);
              return JSON.stringify(normalized, null, 2);
            }

            function renderKeyframes() {
              const container = $('keyframes'); container.replaceChildren();
              track().forEach((frame,index) => {
                const button = document.createElement('button'); button.type='button'; button.textContent=formatTime(frame.timeMs); button.setAttribute('aria-pressed', String(index===selectedIndex));
                button.addEventListener('click', () => { selectedIndex=index; $('time').value=String(frame.timeMs); seek(); refresh(); });
                container.append(button);
              });
              $('delete-keyframe').disabled = track().length <= 2 || selectedIndex === 0;
            }

            function seek() {
              const timeMs = Number($('time').value); $('time-output').value=formatTime(timeMs); $('time-output').textContent=formatTime(timeMs);
              const video = $('video'); if (Number.isFinite(video.duration)) video.currentTime=Math.min(timeMs/1000,video.duration);
              renderProjection();
            }

            function renderProjection() {
              const anchor = anchorAt(track(), Number($('time').value)); const frame = projectionFrame(anchor); const video=$('video');
              Object.assign(video.style,{left:`${frame.left}%`,top:`${frame.top}%`,width:`${frame.width}%`,height:`${frame.height}%`,objectFit:'contain'});
              Object.assign($('crosshair').style,{left:`${50}%`,top:`${50}%`});
              const area=state.safeAreas[activeMode], overlay=$('safe-overlay'); overlay.hidden=!area;
              if (area) Object.assign(overlay.style,{left:`${frame.left+area.x*frame.width}%`,top:`${frame.top+area.y*frame.height}%`,width:`${area.width*frame.width}%`,height:`${area.height*frame.height}%`});
            }

            function refresh() {
              const frame=currentFrame(); setAnchorX(frame.x); setAnchorY(frame.y); setAnchorScale(frame.scale);
              const area=state.safeAreas[activeMode]; $('safe-enabled').checked=Boolean(area); $('safe-controls').hidden=!area;
              if (area) for (const key of ['x','y','width','height']) safeSetters[key](area[key]);
              renderProjection(); renderKeyframes(); const error=validate(); $('receipt').value=receiptJSON(); $('copy-receipt').disabled=Boolean(error); $('download-receipt').disabled=Boolean(error);
              setStatus(error || '\(escape(copy.ready))', Boolean(error));
            }

            function activateMode(mode) {
              activeMode=mode; selectedIndex=0; $('time').value='0'; $('viewport').classList.toggle('pet',mode==='pet');
              document.querySelectorAll('[data-mode]').forEach(button => button.setAttribute('aria-pressed',String(button.dataset.mode===mode)));
              seek(); refresh();
            }

            document.querySelectorAll('[data-mode]').forEach(button => button.addEventListener('click',()=>activateMode(button.dataset.mode)));
            $('time').addEventListener('input',seek);
            $('safe-enabled').addEventListener('change',event => { if(event.target.checked) safeArea(); else delete state.safeAreas[activeMode]; refresh(); });
            $('add-keyframe').addEventListener('click',()=>{ const timeMs=Number($('time').value), frames=track(), existing=frames.findIndex(frame=>frame.timeMs===timeMs); if(existing>=0){selectedIndex=existing;}else if(frames.length<32){frames.push(anchorAt(frames,timeMs));frames.sort((a,b)=>a.timeMs-b.timeMs);selectedIndex=frames.findIndex(frame=>frame.timeMs===timeMs);} refresh(); });
            $('delete-keyframe').addEventListener('click',()=>{ if(track().length>2&&selectedIndex>0){track().splice(selectedIndex,1);selectedIndex=Math.max(0,selectedIndex-1);$('time').value=String(currentFrame().timeMs);seek();refresh();} });
            $('reset-mode').addEventListener('click',()=>{ state.focalTracks[activeMode]=JSON.parse(JSON.stringify(original.focalTracks[activeMode])); if(original.safeAreas[activeMode])state.safeAreas[activeMode]=JSON.parse(JSON.stringify(original.safeAreas[activeMode]));else delete state.safeAreas[activeMode];selectedIndex=0;$('time').value='0';seek();refresh(); });
            $('copy-receipt').addEventListener('click',async()=>{ const text=receiptJSON(); try{await navigator.clipboard.writeText(text);}catch(_){$('receipt').focus();$('receipt').select();document.execCommand('copy');}setStatus('\(escape(copy.copied))'); });
            $('download-receipt').addEventListener('click',()=>{ const blob=new Blob([receiptJSON()],{type:'application/json'}),url=URL.createObjectURL(blob),link=document.createElement('a');link.href=url;link.download=`${state.assetID}.projection.json`;link.click();setTimeout(()=>URL.revokeObjectURL(url),0);setStatus('\(escape(copy.downloaded))'); });
            if(!geometrySelfCheck()){setStatus('\(escape(copy.geometryFailed))',true);document.querySelectorAll('button').forEach(button=>button.disabled=true);return;}
            activateMode('pet');
          })();
          </script>
        </body>
        </html>
        """
    }

    private struct Copy {
        let chinese: Bool
        var language: String { chinese ? "zh-Hans" : "en" }
        var title: String { chinese ? "投影焦点与安全区编辑器" : "Projection focal and safe-area editor" }
        var subtitle: String { chinese ? "在本机校准三种展示形态；不会上传媒体，也不会直接改写内容包。" : "Calibrate all three presentations locally. Media is never uploaded and the pack is not modified directly." }
        var privacy: String { chinese ? "离线 · 无远程请求 · 仅导出数据回执" : "Offline · no remote requests · data receipt export only" }
        var skip: String { chinese ? "跳到编辑控件" : "Skip to editor controls" }
        var preview: String { chinese ? "实时预览" : "Live preview" }
        var mode: String { chinese ? "展示形态" : "Presentation mode" }
        var videoLabel: String { chinese ? "本地内容包视频预览" : "Local content-pack video preview" }
        var timeline: String { chinese ? "视频时间线" : "Video timeline" }
        var keyframes: String { chinese ? "焦点关键帧" : "Focal keyframes" }
        var addKeyframe: String { chinese ? "在当前时间添加／替换" : "Add or replace at current time" }
        var deleteKeyframe: String { chinese ? "删除所选关键帧" : "Delete selected keyframe" }
        var resetMode: String { chinese ? "重置当前形态" : "Reset current mode" }
        var controls: String { chinese ? "所选关键帧" : "Selected keyframe" }
        var scale: String { chinese ? "缩放" : "Scale" }
        var safeArea: String { chinese ? "启用安全区" : "Enable safe area" }
        var width: String { chinese ? "宽度" : "Width" }
        var height: String { chinese ? "高度" : "Height" }
        var safeHint: String { chinese ? "绿色框必须在该形态的所有关键帧中保持可见。" : "The green region must remain visible at every keyframe in this mode." }
        var receipt: String { chinese ? "投影创作回执" : "Projection authoring receipt" }
        var copy: String { chinese ? "复制 JSON" : "Copy JSON" }
        var download: String { chinese ? "下载回执" : "Download receipt" }
        var applyHint: String { chinese ? "回执不代表权利批准。用 apply-content-pack-projection.py 事务写入，再运行严格审计。" : "This receipt is not rights approval. Apply it transactionally with apply-content-pack-projection.py, then run the strict audit." }
        var invalidTrack: String { chinese ? "焦点轨道无效：" : "Invalid focal track:" }
        var safeOutside: String { chinese ? "安全区在某个关键帧中不可见：" : "Safe area is not visible at every keyframe:" }
        var ready: String { chinese ? "构图有效，可以导出回执。" : "Projection is valid and ready to export." }
        var copied: String { chinese ? "已复制回执。" : "Receipt copied." }
        var downloaded: String { chinese ? "已下载回执。" : "Receipt downloaded." }
        var geometryFailed: String { chinese ? "共享投影几何自检失败，导出已禁用。" : "Shared projection geometry self-check failed; export is disabled." }
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
