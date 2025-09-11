import asyncio
import sys
from playwright.async_api import async_playwright

async def check_petcare_app():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False)
        page = await browser.new_page()
        
        try:
            # Flutter 개발 서버는 보통 여러 포트에서 실행됨
            urls_to_try = [
                'http://localhost:8080',
                'http://localhost:8081', 
                'http://localhost:8082',
                'http://localhost:3000',
                'http://localhost:5000'
            ]
            
            app_found = False
            for url in urls_to_try:
                try:
                    print(f'시도 중: {url}')
                    await page.goto(url, timeout=5000)
                    
                    # Flutter 앱 로딩 기다리기
                    await page.wait_for_timeout(3000)
                    
                    # 페이지 제목 확인
                    title = await page.title()
                    print(f'페이지 제목: {title}')
                    
                    # PetCare 관련 텍스트가 있는지 확인
                    content = await page.content()
                    
                    if 'petcare' in title.lower() or 'flutter' in content.lower():
                        print(f'✅ PetCare 앱을 {url}에서 찾았습니다!')
                        
                        # 하단 네비게이션 확인
                        try:
                            nav_items = await page.query_selector_all('[role="button"]')
                            print(f'네비게이션 버튼 수: {len(nav_items)}')
                            
                            # 탭 텍스트 확인
                            page_text = await page.inner_text('body')
                            if '프로필' in page_text or '기록' in page_text or '설정' in page_text:
                                print('✅ 한국어 탭 발견!')
                            
                            if 'Coming Soon' in page_text:
                                print('✅ Coming Soon 메시지 발견!')
                                
                        except Exception as e:
                            print(f'네비게이션 확인 중 오류: {e}')
                        
                        # 스크린샷 저장
                        await page.screenshot(path='petcare_screenshot.png')
                        print('📸 스크린샷 저장됨: petcare_screenshot.png')
                        
                        app_found = True
                        break
                        
                except Exception as e:
                    print(f'{url} 접속 실패: {str(e)[:100]}')
                    continue
            
            if not app_found:
                print('❌ PetCare 앱을 찾을 수 없습니다.')
                print('Flutter 개발 서버가 실행 중인지 확인해주세요.')
                
        except Exception as e:
            print(f'전체 오류: {e}')
        
        await browser.close()

if __name__ == "__main__":
    asyncio.run(check_petcare_app())

