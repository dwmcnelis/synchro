require 'spec_helper'
require 'synchro'

describe Synchro::Reader do

  let(:article_00a2b2c8de62d800b47f4ae6e2fd0a78) { IO.binread('spec/fixtures/articles/00a2b2c8de62d800b47f4ae6e2fd0a78.xml') }
  let(:article_0a1cecf3eebbf27a16feb663fdd4cef4) { IO.binread('spec/fixtures/articles/0a1cecf3eebbf27a16feb663fdd4cef4.xml') }

  describe '.go' do
    before do
      allow_any_instance_of(IO).to receive(:puts)
    end

    it 'processes succesfully', :vcr => { :cassette_name => 'go', :record => :none } do
      reader = Synchro::Reader.go('http://bitly.com/nuvi-plz')

      expect(reader.redis.get('package:1462899453973')).to eql('2016-05-10T21:04:00+00:00')
      expect(reader.redis.get('article:1462899453973:00a2b2c8de62d800b47f4ae6e2fd0a78')).to eql(article_00a2b2c8de62d800b47f4ae6e2fd0a78)
      expect(reader.redis.get('article:1462899453973:0a1cecf3eebbf27a16feb663fdd4cef4')).to eql(article_0a1cecf3eebbf27a16feb663fdd4cef4)
    end

  end

  describe '.packages' do

    it 'lists packages', :vcr => { :cassette_name => 'go', :record => :none } do
      expect { Synchro::Reader.go('http://bitly.com/nuvi-plz')}.to output("\e[0;92;49mnew package package:1462899453973\e[0m\n\e[0;92;49mdownload package package:1462899453973 (9.9M)\e[0m\n\e[0;92;49mnew article article:1462899453973:00a2b2c8de62d800b47f4ae6e2fd0a78\e[0m\n\e[0;92;49mnew article article:1462899453973:0a1cecf3eebbf27a16feb663fdd4cef4\e[0m\n").to_stdout
      expect { Synchro::Reader.packages }.to output("1462899453973\n").to_stdout
    end

  end


  describe '.articles' do

    it 'lists articles', :vcr => { :cassette_name => 'go', :record => :none } do
      expect { Synchro::Reader.go('http://bitly.com/nuvi-plz')}.to output("\e[0;92;49mnew package package:1462899453973\e[0m\n\e[0;92;49mdownload package package:1462899453973 (9.9M)\e[0m\n\e[0;92;49mnew article article:1462899453973:00a2b2c8de62d800b47f4ae6e2fd0a78\e[0m\n\e[0;92;49mnew article article:1462899453973:0a1cecf3eebbf27a16feb663fdd4cef4\e[0m\n").to_stdout
      expect { Synchro::Reader.articles('1462899453973') }.to output("1462899453973:00a2b2c8de62d800b47f4ae6e2fd0a78\n1462899453973:0a1cecf3eebbf27a16feb663fdd4cef4\n").to_stdout
    end

  end


  describe '.article' do

    it 'retrieves article', :vcr => { :cassette_name => 'go', :record => :none } do
      expect { Synchro::Reader.go('http://bitly.com/nuvi-plz')}.to output("\e[0;92;49mnew package package:1462899453973\e[0m\n\e[0;92;49mdownload package package:1462899453973 (9.9M)\e[0m\n\e[0;92;49mnew article article:1462899453973:00a2b2c8de62d800b47f4ae6e2fd0a78\e[0m\n\e[0;92;49mnew article article:1462899453973:0a1cecf3eebbf27a16feb663fdd4cef4\e[0m\n").to_stdout
      expect { Synchro::Reader.article('1462899453973:00a2b2c8de62d800b47f4ae6e2fd0a78') }.to output(IO.read('spec/fixtures/articles/00a2b2c8de62d800b47f4ae6e2fd0a78.xml')).to_stdout
    end

  end


  describe '.flush' do
    before do
      allow_any_instance_of(IO).to receive(:puts)
    end

    it 'flushes packages and articles', :vcr => { :cassette_name => 'go', :record => :none } do
      reader = Synchro::Reader.go('http://bitly.com/nuvi-plz')
      Synchro::Reader.flush

      expect(reader.redis.keys('package:*')).to eql([])
      expect(reader.redis.keys('article:*:*')).to eql([])
    end

  end


end
