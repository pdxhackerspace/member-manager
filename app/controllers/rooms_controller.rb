class RoomsController < AdminController
  before_action :set_room, only: %i[edit update destroy]

  def index
    @rooms = Room.ordered
  end

  def new
    @room = Room.new
  end

  def edit; end

  def create
    @room = Room.new(room_params)
    if @room.save
      redirect_to rooms_path, notice: 'Room created successfully.'
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @room.update(room_params)
      redirect_to rooms_path, notice: 'Room updated successfully.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @room.destroy!
    redirect_to rooms_path, notice: 'Room deleted.'
  end

  private

  def set_room
    @room = Room.find(params[:id])
  end

  def room_params
    params.expect(room: %i[name position])
  end
end
