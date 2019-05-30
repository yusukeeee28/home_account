# -*- coding: utf-8 -*-                                                       
require 'webrick'
require 'erb'
require 'rubygems'
require 'dbi'

#Stringクラスのconcatメソッドを
#置き換えるパッチ
class String
  alias_method(:orig_concat, :concat)
  def concat(value)
    if RUBY_VERSION > "1.9"
      orig_concat value.force_encoding('UTF-8')
    else
      orig_concat value
    end
  end
end

config = {
  :Port => 8000,
  :DocumentRoot => '.',
}

#拡張子erbのファイルを、ERBを呼び出して処理するERBHandlerと関連づける
WEBrick::HTTPServlet::FileHandler.add_handler("erb", WEBrick::HTTPServlet::ERBHandler)

#WEBRickのHTTP　Serverクラスのサーバーインスタンスを作成する

server = WEBrick::HTTPServer.new( config )

#erbのMINEタイプを設定
server.config[:MimeTypes]["erb"] = "text/html"

#一覧表示からの処理
# "http://localhost:8000/list" で呼び出される
server.mount_proc("/list"){| req, res |
  p req.query['operation']
  if req.query['operation'] == nil then
    req.query['operation'] = "&"
  end
  word = req.query['operation'].gsub(/&/," ")
  
  # 'operation'の値の後の(.delete, .edit)で処理を分岐する
  if /(.*)\.(delete|edit)$/ =~ word
    target_id = $1
    operation = $2
    # p req.query
    #選択された処理を実行する画面に移行する
    #ERBを、ERBHandlerを経由せずに直接呼び出して利用している
    if operation == 'delete'
      template = ERB.new( File.read('delete.erb'))
    elsif operation == 'edit'
      template = ERB.new( File.read('edit.erb'))
    end
    res.body << template.result(binding)
  else #データが選択されていないなど
    template = ERB.new( File.read('noselected.erb'))
    res.body << template.result(binding)
  end
}

# 登録の処理
# "http://localhost:8000/entry"で呼び出される
server.mount_proc("/entry"){ |req, res|
  #(注意)本来ならここで入力データに危険や
  #不正がないかチェックするが、演習の見通しのために割愛している
  # p req.query
  #dbhを作成し、データベース'account.db'に接続する
  dbh=DBI.connect('DBI:SQLite3:account.db')
  #テーブルにデータを追加する（長いので折り返している）
  dbh.do("insert into account \
    values(current_timestamp,'#{req.query['DATE']}',\
    '#{req.query['Name']}', '#{req.query['Value']}',\
    '#{req.query['Income']}','#{req.query['Balance']}');")
  #データベースとの接続を終了する %>
  dbh.disconnect

  #処理の結果を表示する
  #ERBを、ERBHandlerを経由せずに直接呼び出して利用している
  template =ERB.new( File.read('entried.erb') )
  res.body << template.result( binding )
  
}
#一覧表示からの処理
# "http://localhost:8000/list" で呼び出される
server.mount_proc("/login"){| req, res |
  p req.query
  
  #検索条件の整理
  a=['ID','PASSWORD']
  #問い合わせ条件のある要素以外を削除
  a.delete_if{|name| req.query[name] == ""}
  check = 1
  if req.query['ID'] == "" then
    check=0
  elsif req.query['PASSWORD'] == "" then
    check=0
  end
  
  check_id =0
  check_pass = 0
  if check ==1 then
    dbh=DBI.connect('DBI:SQLite3:account.db')
    dbh.select_all("select * from login;") do |row|
      ['ID', 'PASSWORD'].each do |name| 
        p row[name]
        if name == 'ID' && row[name] == req.query['ID'] then
          check_id =1
        end
        if check_id == 1 && name == 'PASSWORD' && row[name] == req.query['PASSWORD'] then
          check_pass = 1
        end
      end
    end
  end
  if check_id == 1 && check_pass == 1 then
    template = ERB.new(File.read('list.erb'))
    res.body << template.result( binding )
  else
    template = ERB.new(File.read('failedlogin.erb'))
    res.body << template.result( binding )
  end 
  
}
#一覧表示からの処理
# "http://localhost:8000/list" で呼び出される
server.mount_proc("/signin"){| req, res |
  p req.query
  check=1
  if req.query['ID'] == '' then
    check=0
  elsif req.query['PASSWORD'] == '' then
    check=0
  end
  if check==0 then
    template =ERB.new( File.read('nosignup.erb') )
    res.body << template.result( binding )
  elsif check==1 then
    dbh=DBI.connect('DBI:SQLite3:account.db')
    dbh.do("insert into login values('#{req.query['ID']}','#{req.query['PASSWORD']}');")
    dbh.disconnect
    template =ERB.new( File.read('succsignup.erb') )
    res.body << template.result( binding )
  end

}

#修正の処理
# "http://localhost:8000/edit"で呼び出される
server.mount_proc("/edit"){|req, res|
  #(注意)本来ならここで入力データに危険や
  #不正がないかチェックするが、演習の見通しに割愛している
  # p req.query
  #dbhを作成し、データベース'account.db'に接続する
  dbh = DBI.connect( 'DBI:SQLite3:account.db')
  #テーブルのデータを更新する(長いので折り返している)
  dbh.do("update account set ID=current_timestamp,\
    DATE='#{req.query['DATE']}',Name='#{req.query['Name']}',\
    Value='#{req.query['Value']}', Income='#{req.query['Income']}', Balance='#{req.query['Balance']}' where ID = '#{req.query['ID']}';")#拡張3
  #データベースとの接続を終了する %>
  dbh.disconnect
  #処理の結果を表示する
  #ERBを、ERBHandlerを経由せずに直接呼び出して利用している
  template = ERB.new(File.read('edited.erb'))
  res.body << template.result( binding )
}

#削除の処理
# "http://localhost:8000/delete"で呼び出される
server.mount_proc("/delete"){|req, res|
  #(注意)本来ならここで入力データに危険や
  #不正がないかチェックするが、演習の見通しに割愛している
  p req.query
  #dbhを作成し、データベース'account.db'に接続する
  dbh = DBI.connect( 'DBI:SQLite3:account.db')

  #テーブルからデータを削除する
  dbh.do("delete from account where ID='#{req.query['ID']}';")

  #データベースとの接続を終了する
  dbh.disconnect
  #処理の結果を表示する
  #ERBを、ERBHandlerを経由せずに直接呼び出して利用している
  template = ERB.new(File.read('deleted.erb'))
  res.body << template.result( binding )
}
#Ctrl-Cで割り込みがあった場合にサーバーを停止する処理を登録しておく
trap(:INT) do
  server.shutdown
end

#上記記述の処理をこなすサーバーを開始する
server.start