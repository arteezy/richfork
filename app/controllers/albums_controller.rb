class AlbumsController < ApplicationController
  before_action :set_album, only: [:show, :edit, :update, :destroy]

  # GET /albums
  # GET /albums.json
  def index
    params[:order]  ||= 'date'
    params[:dir]    ||= 'desc'
    params[:rating] ||= '0.0-10.0'

    rating = params[:rating].split('-')
    min_rating = rating[0]
    max_rating = rating[1]

    @albums = Album.artist(params[:artist])
                   .year(params[:year])
                   .genre(params[:genre])
                   .label(params[:label])
                   .reissue(params[:reissue])
                   .bnm(params[:bnm])
                   .rating_range(min_rating, max_rating)
                   .albums_order(params[:order], params[:dir])
                   .search(params[:search])
                   .page(params[:page])

    @albums_page_count = Rails.cache.fetch ['albums_count', params], expires_in: 2.hours do
      (@albums.count / Kaminari.config.default_per_page.to_f).ceil
    end
  end

  # GET /api/artists.json
  def artists
    @artists = Rails.cache.fetch 'artists', expires_in: 2.hours do
      Album.distinct('artist').sort
    end
  end

  # GET /api/labels.json
  def labels
    @labels = Rails.cache.fetch 'labels', expires_in: 2.hours do
      Album.distinct('label').sort
    end
  end

  # GET /albums/search
  def search
    albums = Album.search(params[:search])
    albums = albums.desc(:updated_at) if params[:lastupdated]
    @albums = albums.page(params[:page])
    authorize @albums
  end

  # GET /albums/stats
  # GET /albums/stats.json
  def stats
    pipeline = []
    pipeline << {
      '$match' => {
        'date' => {
          '$gte' => Date.new(params[:year].to_i, 1, 1),
          '$lte' => Date.new(params[:year].to_i, 12, 31)
        }
      }
    } if params[:year]
    pipeline << {
      '$group' => {
        '_id' => '$date',
        'avg_rating' => { '$avg' => '$rating' }
      }
    }
    pipeline << { '$sort' => { '_id' => 1 } }

    stats = Album.collection.aggregate(pipeline)

    @total = {
      album: Album.year(params[:year]).count,
      bnm: Album.year(params[:year]).where(bnm: true).count,
      reissue: Album.year(params[:year]).where(reissue: true).count,
      discogs: Album.year(params[:year]).not.where(discogs: nil).count
    }

    respond_to do |format|
      format.html { render :stats }
      format.json { render json: stats }
    end
  end

  # GET /albums/1
  # GET /albums/1.json
  def show
    @comments = @album.comments.all

    return unless user_signed_in?
    @comment = @album.comments.build

    if @album.rates.where(user_id: current_user.id).exists?
      @rate = @album.rates.find_by(user_id: current_user.id)
    end

    return unless @current_user.lists.opened.present?
    @lists = @current_user.lists.opened - @album.lists
  end

  # GET /albums/new
  def new
    @album = Album.new
    authorize @album
  end

  # GET /albums/1/edit
  def edit
    authorize @album
  end

  # POST /albums
  # POST /albums.json
  def create
    @album = Album.new(album_params)
    authorize @album

    respond_to do |format|
      if @album.save
        format.html { redirect_to @album, notice: 'Album was successfully created' }
        format.json { render :show, status: :created, location: @album }
      else
        format.html { render :new }
        format.json { render json: @album.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /albums/1
  # PATCH/PUT /albums/1.json
  def update
    if album_params[:list_id]
      list = List.find(album_params[:list_id])
      @album.lists.push(list)
      redirect_to list, notice: 'Album was successfully added to this List'
    else
      authorize @album
      respond_to do |format|
        if @album.update(album_params)
          format.html { redirect_to @album, notice: 'Album was successfully updated' }
          format.json { render :show, status: :ok, location: @album }
        else
          format.html { render :edit }
          format.json { render json: @album.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  # DELETE /albums/1
  # DELETE /albums/1.json
  def destroy
    authorize @album
    @album.destroy
    respond_to do |format|
      format.html { redirect_to albums_url, notice: 'Album was successfully destroyed' }
      format.json { head :no_content }
    end
  end

  private

  def set_album
    @album = Album.find(params[:id])
  end

  def album_params
    params.require(:album).permit(:title, :p4k_id, :year, :artwork, :source, :list_id,
      :date, :reviewer, :rating, :reissue, :bnm, artist: [], label: [], genre: [])
  end
end
