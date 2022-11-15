class LineLoginApiController < ApplicationController
  require 'json'
  require 'typhoeus'
  require 'securerandom'

  # WebアプリとLINEプラットフォーム間でのCSRF対策は自前で行うため
  # RailsデフォルトのCSRF対策メソッドは無効化する
  protect_from_forgery except: %i(login callback)

  def login
#debugger
    # CSRF対策用の固有な英数字の文字列
    # ログインセッションごとにWebアプリでランダムに生成する
    session[:state] = SecureRandom.urlsafe_base64

    # ユーザーに認証と認可を要求する
    # https://developers.line.biz/ja/docs/line-login/integrate-line-login/#making-an-authorization-request

    base_authorization_url = 'https://access.line.me/oauth2/v2.1/authorize'
    response_type = 'code'
    client_id = '1657559843' #LINEログインチャネルのチャネルID,本番環境では環境変数などに保管する
    #debugger
    redirect_uri = CGI.escape('https://1ece-111-239-182-153.jp.ngrok.io/line_login_api/callback')#CGI.escape(line_login_api_callback_url)
    state = session[:state]
    scope = 'profile%20openid' #ユーザーに付与を依頼する権限

    authorization_url = "#{base_authorization_url}?response_type=#{response_type}&client_id=#{client_id}&redirect_uri=#{redirect_uri}&state=#{state}&scope=#{scope}"
#debugger
    redirect_to authorization_url, allow_other_host: true
  end

  def callback
#debugger
    # CSRF対策のトークンが一致する場合のみ、ログイン処理を続ける
    if params[:state] == session[:state]

      line_user_id = get_line_user_id(params[:code])
      user = User.find_or_initialize_by(line_user_id: line_user_id)

      if user.save
        session[:user_id] = user.id
        redirect_to root_path, notice: 'ログインしました'
      else
        redirect_to root_path, notice: 'ログインに失敗しました'
      end

    else
      redirect_to root_path, notice: '不正なアクセスです'
    end

  end

  private

  def get_line_user_id(code)

    # ユーザーのIDトークンからプロフィール情報（ユーザーID）を取得する
    # https://developers.line.biz/ja/docs/line-login/verify-id-token/

    line_user_id_token = get_line_user_id_token(code)

    if line_user_id_token.present?

      url = 'https://api.line.me/oauth2/v2.1/verify'
      options = {
        body: {
          id_token: line_user_id_token,
          client_id: '1657559843' # LINEログインチャネルのチャネルID,本番環境では環境変数などに保管
        }
      }

      response = Typhoeus::Request.post(url, options)

      if response.code == 200
        JSON.parse(response.body)['sub']
      else
        nil
      end
    
    else
      nil
    end

  end

  def get_line_user_id_token(code)

    # ユーザーのアクセストークン（IDトークン）を取得する
    # https://developers.line.biz/ja/reference/line-login/#issue-access-token

    url = 'https://api.line.me/oauth2/v2.1/token'
    redirect_uri = line_login_api_callback_url#'https://1ece-111-239-182-153.jp.ngrok.io/line_login_api/callback'

    options = {
      headers: {
        'Content-Type' => 'application/x-www-form-urlencoded'
      },
      body: {
        grant_type: 'authorization_code',
        code: code,
        redirect_uri: redirect_uri,
        client_id: '1657559843', # LINEログインチャネルのチャネルID,本番環境では環境変数などに保管
        client_secret: 'dd8bd335477304645a28ff5c2b8f0270' # LINEログインチャネルのチャネルシークレット,本番環境では環境変数などに保管
      }
    }
    response = Typhoeus::Request.post(url, options)

    if response.code == 200
      JSON.parse(response.body)['id_token'] # ユーザー情報を含むJSONウェブトークン（JWT）
    else
      nil
    end
  end

end